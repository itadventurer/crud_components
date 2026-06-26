class ColumnHeadersController < ApplicationController
  # Custom column headers + per-column actions on a DynamicColumn — the matrix
  # shape (books × properties) where every column *is* a domain object. Each
  # PropertyDefinition becomes a column whose `<th>` carries:
  #   - a link (to a fake "definition" page), and
  #   - an `on: :selection` bulk action: it submits the shared select-form, so it
  #     acts on the *ticked* rows × this column's object. Declaring it makes the
  #     collection selectable (checkboxes appear) with no extra wiring.
  # The header block and both action path blocks close over the definition.
  def index
    @books = Book.all
    @columns = PropertyDefinition.order(:id).map do |defn|
      CrudComponents::DynamicColumn.new(
        defn.key.to_sym,
        label: defn.label,
        as: defn.renderer,
        header: -> { link_to defn.label, columns_path(anchor: defn.key) },
        header_actions: [
          CrudComponents::Action.new(:tag_selected, on: :selection, icon: 'tag', method: :post) do
            tag_column_headers_path(key: defn.key)
          end
        ],
        preload: ->(records) { defn.values_by_subject(Book, records) }
      ) { |record, loaded| defn.cast(loaded[record.id]&.value) }
    end

    # A render: cell block that reads its preload:-ed value — only possible now
    # that render_cell passes the value as the block's second argument.
    shelf = PropertyDefinition.find_by(key: 'shelf')
    if shelf
      @columns << CrudComponents::DynamicColumn.new(
        :shelf_tag, label: 'Shelf tag',
        preload: ->(records) { shelf.values_by_subject(Book, records) },
        render: ->(record, value) { content_tag(:span, "tag:#{value}", class: 'shelf-tag') }
      ) { |record, loaded| loaded[record.id]&.value }
    end
  end

  # The header selection action's target: the row checkboxes submit the shared
  # select-form, so `selected[]` arrives here. The gem resolves it back to the
  # ticked books; this column's object is the `key` query param. Just reports the
  # count + a few titles so the effect is visible (and assertable).
  def tag
    books = CrudComponents.selected(Book, params)
    titles = books.limit(3).pluck(:title)
    redirect_to column_headers_path,
                notice: "Tagged #{books.count} book(s) for '#{params[:key]}': #{titles.join(', ')}"
  end
end
