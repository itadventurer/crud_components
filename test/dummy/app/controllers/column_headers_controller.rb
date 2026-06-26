class ColumnHeadersController < ApplicationController
  # Custom column headers + per-column actions on a DynamicColumn. Each
  # PropertyDefinition becomes a column whose `<th>` carries a link (to a fake
  # "definition" page) and a POST "touch all" bulk action — the kind of
  # per-column controls a matrix view (mails × participants) needs. The header
  # block and the action's path block both close over the definition.
  def index
    @books = Book.all
    @columns = PropertyDefinition.order(:id).map do |defn|
      CrudComponents::DynamicColumn.new(
        defn.key.to_sym,
        label: defn.label,
        as: defn.renderer,
        header: -> { link_to defn.label, columns_path(anchor: defn.key) },
        header_actions: [
          CrudComponents::Action.new(:touch_all, icon: 'arrow-repeat', method: :post) do
            touch_all_column_headers_path(key: defn.key)
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

  # The header action target — just bounces back; the test asserts the form, not
  # the side effect.
  def touch_all
    redirect_to column_headers_path
  end
end
