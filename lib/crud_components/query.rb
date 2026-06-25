module CrudComponents
  # Applies URL params to a relation: filtering, global search, sorting.
  #
  # The uniform rule: a param is applied iff it names a filterable field of
  # the fieldset in play that the current user may see (or one of the
  # reserved params q/sort/dir/page/per). Everything else never reaches SQL.
  class Query
    SORT_DIRECTIONS = %w[asc desc].freeze

    attr_reader :model, :structure, :fieldset, :param_prefix

    def initialize(model, params, fieldset: nil, ability: nil, param_prefix: nil, extra_fields: [])
      @model = model
      @structure = Structure.for(model)
      @fieldset = fieldset.is_a?(Fieldset) ? fieldset : @structure.fieldset(fieldset)
      @params = extract(params)
      @permission = PermissionContext.new(ability)
      @param_prefix = param_prefix
      @extra_fields = extra_fields
    end

    def apply(scope)
      scope = apply_filters(scope)
      scope = apply_search(scope)
      apply_sort(scope)
    end

    def fieldset_name = fieldset.name

    def filter_fields
      (structure.fieldset_filter_fields(fieldset) + @extra_fields.select(&:filterable?))
        .select { |f| f.permitted?(@permission) }
    end

    def sortable_fields
      (structure.fieldset_sortable_fields(fieldset) + @extra_fields.select(&:sortable?))
        .select { |f| f.permitted?(@permission) }
    end

    def searchable? = structure.searchable?

    # Current value of a (logical, unprefixed) param — for filter controls.
    def value(key) = param(key)

    def active?
      keys = filter_fields.flat_map { |f| [f.name.to_s, "#{f.name}_geq", "#{f.name}_leq"] }
      (keys + ['q']).any? { |key| param(key) }
    end

    # [field_name_string, direction_string] or nil.
    def sort_state
      field = current_sort_field
      field && [field.name.to_s, direction]
    end

    def param_name(key) = "#{prefix}#{key}"

    private

    def prefix = param_prefix ? "#{param_prefix}_" : ''

    def param(key)
      raw = @params[param_name(key)]
      raw.is_a?(String) && raw.present? ? raw : nil
    end

    def extract(params)
      hash = if params.respond_to?(:to_unsafe_h)
               params.to_unsafe_h
             else
               params.to_h
             end
      hash.transform_keys(&:to_s)
    end

    def apply_filters(scope)
      filter_fields.reduce(scope) do |current, field|
        exact = param(field.name.to_s)
        geq = param("#{field.name}_geq")
        leq = param("#{field.name}_leq")
        next current unless exact || geq || leq

        field.apply_filter(current, exact: exact, geq: geq, leq: leq)
      end
    end

    def apply_search(scope)
      q = param('q')
      return scope unless q && structure.searchable?

      structure.apply_search(scope, q, permission: @permission)
    end

    def current_sort_field
      sort = param('sort')
      sort && sortable_fields.find { |f| f.name.to_s == sort }
    end

    def direction
      SORT_DIRECTIONS.include?(param('dir')) ? param('dir') : 'asc'
    end

    def apply_sort(scope)
      field = current_sort_field
      return scope unless field

      field.apply_sort(scope, direction.to_sym)
    end
  end
end
