module CrudComponents
  module Fields
    # A present / absent filter for association and attachment columns, where a
    # value match makes no sense but "has one / has none" is the natural question.
    # It renders a 3-state control (any / present / absent) and composes into the
    # query as an EXISTS / NOT EXISTS — `where.associated` / `where.missing` on
    # the reflection — so it joins automatically and stacks with the rest of the
    # filters and the security rule like any other field.
    #
    # An including field names the reflection to test via {#presence_association}
    # (the column name by default; an attachment field points at its underlying
    # *_attachment(s) association). A field that also has a value filter of its own
    # (a belongs_to) keeps it and reaches {#apply_presence_filter} only for the
    # branch that wants presence.
    module PresenceFilter
      def derived_filterable? = true

      def derived_filter_control = :presence

      def apply_derived_filter(scope, value: nil, **)
        apply_presence_filter(scope, value)
      end

      # present → rows that have the association, absent → rows that don't; a blank
      # or unknown value leaves the scope untouched (the "any" choice).
      def apply_presence_filter(scope, value)
        case value
        when CrudComponents::PRESENT_FILTER_VALUE then scope.where.associated(presence_association)
        when CrudComponents::ABSENT_FILTER_VALUE  then scope.where.missing(presence_association)
        else scope
        end
      end

      # The reflection name `where.associated` / `where.missing` join through.
      def presence_association = name
    end
  end
end
