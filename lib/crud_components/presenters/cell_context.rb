module CrudComponents
  module Presenters
    # Passed to value renderers so a cell can offer click-to-filter (enum
    # badges, boolean icons) — respecting the active query's fieldset
    # whitelist and param_prefix. Nil on surfaces without a query (the record
    # page, static collections), so renderers must null-check it.
    class CellContext
      def initialize(view:, query:)
        @view = view
        @query = query
      end

      # Is this field one the current query would actually act on?
      def filterable?(field)
        @query.filter_fields.include?(field)
      end

      # A URL that adds (or replaces) this field's filter, keeping every other
      # active param — prefixed correctly for multi-collection pages.
      def filter_url(field, value)
        params = @view.request.query_parameters.merge(
          @query.param_name(field.name.to_s) => value.to_s
        )
        "#{@view.request.path}?#{params.to_query}"
      end
    end
  end
end
