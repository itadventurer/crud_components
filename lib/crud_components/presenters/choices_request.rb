# frozen_string_literal: true

module CrudComponents
  module Presenters
    # Answers a combobox filter's suggestion request (see
    # Query::CHOICES_PARAM) for a presenter with a `query`. The combobox fetches
    # the page it sits on and picks the `filters/_choices` fragment out of the
    # response, so the suggestions come from the same controller, ability and
    # base scope as the list itself.
    module ChoicesRequest
      # Whether this request asks for suggestions rather than the page.
      def choices_request?
        !query.nil? && !query.choices_request.nil?
      end

      # The suggestions as the `filters/_choices` fragment. A name that is not a
      # filter of this query (unknown, hidden, or not an association) gets an
      # empty list. `source` tells two answering helpers on one page apart.
      def render_choices(source:)
        name, field, term = query.choices_request
        suggestions = field ? field.filter_suggestions(query, term) : []
        view.render('crud_components/filters/choices',
                    suggestions: suggestions, param_name: query.param_name(name), source: source)
      end
    end
  end
end
