# STI base — Manual (manual.rb) inherits its crud_structure. Reflection coverage.
class Document < ApplicationRecord
  include CrudComponents::Model

  crud_structure do
    label :title
    fieldset :index, %i[title body]
  end
end
