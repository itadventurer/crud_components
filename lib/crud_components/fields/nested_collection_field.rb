# frozen_string_literal: true

module CrudComponents
  module Fields
    # A has_many whose rows are edited in the parent's form, asked for with
    # `nested:`. The index still shows the truncated list of links and filters
    # by the children's label; the form renders one block per row, a (+) for the
    # next and a "remove" box per row.
    class NestedCollectionField < HasManyField
      include NestedForm
    end
  end
end
