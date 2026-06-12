module CrudComponents
  module Presenters
    # The single `filter` local of the standalone filter form partial.
    # Renders the fieldset's filterable fields (including its `filters:`
    # extension); never auto-submits — users compose several filters here.
    class Filter < Base
      attr_reader :model, :structure, :query

      def initialize(view:, model:, fieldset: nil, query: nil, param_prefix: nil)
        super(view: view)
        @model = model.is_a?(Class) ? model : model.klass
        @structure = Structure.for(@model)
        @query = if query.is_a?(Query)
                   query
                 else
                   Query.new(@model, view.request.query_parameters,
                             fieldset: @structure.fieldset(fieldset || :index),
                             ability: ability, param_prefix: param_prefix)
                 end
      end

      def fields = query.filter_fields
      def searchable? = query.searchable?
      def form_path = view.request.path
      def reset_path = view.request.path

      def param_name(key) = query.param_name(key)
      def value(key) = query.value(key)

      # Keep sort and foreign params; our own controls resubmit themselves.
      def preserved_params
        own = fields.flat_map { |f| [param_name(f.name.to_s), param_name("#{f.name}_geq"), param_name("#{f.name}_leq")] }
        own += [param_name('q'), param_name('page'), param_name('per')]
        view.request.query_parameters.reject { |key, _| own.include?(key) }
      end
    end
  end
end
