class CustomFieldsController < ApplicationController
  # Dynamic columns: user-defined properties that live outside the Book table
  # (here in property_values), shown as extra columns. The model knows nothing
  # about them — the controller loads the definitions and turns each into a
  # CrudComponents::DynamicColumn, then `crud_collection` renders them alongside
  # the declared columns. They filter and sort because each column carries the
  # facets that reach the value store.
  def index
    @books = Book.all
    @columns = PropertyDefinition.order(:id).map { |defn| defn.to_crud_column(Book) }
  end
end
