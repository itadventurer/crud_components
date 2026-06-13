require 'test_helper'

# The form side: the permit list (the single source of truth that keeps form
# and strong-params in lockstep) and the editable/visible/read-only logic.
class FormTest < ActiveSupport::TestCase
  def permit(action = :update, ability: nil)
    CrudComponents.permitted_attributes(Book, action: action, ability: ability)
  end

  test 'permit list = editable, permitted, form-capable fields' do
    list = permit(:update, ability: CrudTestHelpers::AllowAll.new)
    assert_includes list, :title
    assert_includes list, :publisher_id        # belongs_to → foreign key
    assert_includes list, ({ author_ids: [] }) # habtm → ids array
    assert_includes list, :cover               # attachment
    assert_includes list, :active              # editable: :manage, granted
    assert_includes list, :purchase_price      # if: :manage, granted
  end

  test 'permit list excludes non-editable, computed and association-display fields' do
    list = permit(:update, ability: CrudTestHelpers::AllowAll.new)
    refute_includes list, :slug          # editable: false
    refute_includes list, :id
    refute_includes list, :created_at
    refute_includes list, :shop_margin   # computed — no form control
    refute_includes list, :reviews       # has_many (non-habtm) — not editable
  end

  test 'permit list is permission-aware (visibility and editability)' do
    list = permit(:update, ability: nil)
    refute_includes list, :purchase_price  # if: :manage — not even visible
    refute_includes list, :active          # editable: :manage — visible but not editable
    assert_includes list, :title
  end

  test 'Model.crud_attribute_names mirrors the module method' do
    assert_equal CrudComponents.permitted_attributes(Book, action: :update, ability: nil),
                 Book.crud_attribute_names(:update, ability: nil)
  end

  test 'a zero-config model still yields a derived permit list' do
    list = CrudComponents.permitted_attributes(Author)
    assert_includes list, :name
    assert_includes list, :email
    assert_includes list, ({ book_ids: [] })   # habtm, derived from the schema
    refute_includes list, :id
    refute_includes list, :created_at
  end

  test 'control mapping: input vs read-only vs skipped' do
    structure = structure_of(Book)
    assert structure.field(:title).editable?
    refute structure.field(:slug).editable?            # editable: false → read-only
    assert_nil structure.field(:shop_margin).form_control  # computed → skipped
    assert_equal :belongs_to, structure.field(:publisher).form_control
    assert_equal :habtm, structure.field(:authors).form_control
    assert_equal :file, structure.field(:cover).form_control
  end

  test 'form_fieldset falls back action → :form → :default' do
    structure = structure_of(Book)
    # Book declares :form but not :edit, so :update resolves to :form
    assert_equal :form, structure.form_fieldset(:update).name
    assert_equal :form, structure.form_fieldset(:new).name
    # a model with neither falls all the way back to :default
    assert_equal :default, structure_of(Author).form_fieldset(:edit).name
  end
end
