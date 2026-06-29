module CrudComponents
  module Presenters
    # The single `filter` local of the standalone filter form partial.
    # Renders the fieldset's filterable fields (including its `filters:`
    # extension); never auto-submits — users compose several filters here.
    class Filter < Base
      attr_reader :model, :structure, :query

      def initialize(view:, model:, fieldset: nil, query: nil, param_prefix: nil, extra_columns: nil, sort: false)
        super(view: view)
        @model = model.is_a?(Class) ? model : model.klass
        @structure = Structure.for(@model)
        @sort = sort
        # Dynamic columns become extra query fields, so their filters appear in the
        # form exactly like a declared field's — mirrors crud_collection's
        # extra_columns: (issue #22). A prebuilt query already carries its own.
        dynamic_fields = Array(extra_columns).map { |c| c.to_field(@model) }
        @query = if query.is_a?(Query)
                   query
                 else
                   Query.new(@model, view.request.query_parameters,
                             fieldset: @structure.fieldset(fieldset || :index),
                             ability: ability, param_prefix: param_prefix, extra_fields: dynamic_fields)
                 end
      end

      def fields = query.filter_fields
      def searchable? = query.searchable?
      def form_path = view.request.path
      def reset_path = view.request.path

      def param_name(key) = query.param_name(key)
      def value(key) = query.value(key)

      # ── sorting (headerless surfaces) ──────────────────────────────────────
      # Whether to render the sort picker: asked for, and there's something to
      # sort by. A table carries its own header sort links, so this is opt-in.
      def sort_control? = @sort && query.sortable_fields.any?

      # The fields offered in the sort picker, as [human_name, name] pairs.
      def sort_field_choices
        query.sortable_fields.map { |f| [f.human_name, f.name.to_s] }
      end

      # [field_name, direction] currently in effect, or [nil, 'asc'] when unsorted.
      def sort_state
        current, dir = query.sort_state
        [current, dir || 'asc']
      end

      # Keep foreign params; our own controls resubmit themselves. Sort/dir are
      # kept as hidden inputs (to preserve the current sort across an Apply) unless
      # the sort picker renders them — then they'd duplicate, so we drop them.
      def preserved_params
        own = fields.flat_map { |f| [param_name(f.name.to_s), param_name("#{f.name}_geq"), param_name("#{f.name}_leq")] }
        own += [param_name('q'), param_name('page'), param_name('per')]
        own += [param_name('sort'), param_name('dir')] if sort_control?
        view.request.query_parameters.reject { |key, _| own.include?(key) }
      end
    end
  end
end
