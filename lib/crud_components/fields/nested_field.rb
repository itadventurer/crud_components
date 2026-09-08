# frozen_string_literal: true

module CrudComponents
  module Fields
    # A single record edited in place rather than picked from a list, asked for
    # with `nested:` on a belongs_to or has_one. Everything a picked association
    # does on the index — link, filter, sort, search — it still does; only the
    # form side differs, and that comes from NestedForm.
    class NestedField < BelongsToField
      include NestedForm
    end
  end
end
