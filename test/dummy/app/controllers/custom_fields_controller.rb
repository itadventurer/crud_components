class CustomFieldsController < ApplicationController
  # Dynamic columns: user-defined properties that live outside the Book table
  # (here in property_values), shown as extra columns. The model knows nothing
  # about them — the controller loads the definitions and turns each into a
  # CrudComponents::DynamicColumn, then `crud_collection` renders them alongside
  # the declared columns. They filter and sort because each column carries the
  # facets that reach the value store.
  def index
    @books = Book.all
    @columns = []
    @columns << CrudComponents::DynamicColumn.new(
      :price_usd,
      label: 'Price (USD)',
      as: :number,
      unit: '$',
      filter: ->(scope, geq:, leq:) { scope.where('price*1.1 >= ?', geq).where('price*1.1 <= ?', leq) },
      sort: ->(scope, dir) { scope.order(Arel.sql("(price*1.1) #{dir}")) }
      ) { |record| record.price * 1.1 }
      @columns += PropertyDefinition.order(:id).map { |defn| defn.to_crud_column(Book) }
  end
end
