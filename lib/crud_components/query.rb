# frozen_string_literal: true

module CrudComponents
  # Applies URL params to a relation: filtering, global search, sorting.
  #
  # The uniform rule: a param is applied iff it names a filterable field of
  # the fieldset in play that the current user may see (or one of the
  # reserved params q/sort/dir/page/per). Everything else never reaches SQL.
  class Query
    SORT_DIRECTIONS = %w[asc desc].freeze

    # The reserved params the query itself reads. Pagination (page/per) is the
    # host's — it lives in the controller, never here — so it is not listed.
    RESERVED_PARAMS = %w[q sort dir].freeze

    # The params a combobox filter asks its suggestions with: which field, and
    # the text typed so far. Read by the collection/filter helpers, never by
    # #apply.
    CHOICES_PARAM = 'crud_choices'
    TERM_PARAM = 'crud_term'

    attr_reader :model, :structure, :fieldset, :param_prefix, :ability

    # The relation this query narrows, before any filter, search or sort: the
    # rows the list could show at all (already scoped by the caller — nested,
    # authorized). Association filters offer only the targets occurring in it.
    # nil until #apply has run, unless given; without it, they offer every
    # target the ability may see.
    attr_reader :base_scope

    def initialize(model, params, fieldset: nil, ability: nil, param_prefix: nil, extra_fields: [],
                   base_scope: nil)
      @model = model
      @structure = Structure.for(model)
      @fieldset = fieldset.is_a?(Fieldset) ? fieldset : @structure.fieldset(fieldset)
      @params = extract(params)
      @ability = ability
      @permission = PermissionContext.new(ability)
      @param_prefix = param_prefix
      @extra_fields = extra_fields
      @base_scope = base_scope
    end

    def apply(scope)
      @base_scope ||= scope if scope.is_a?(ActiveRecord::Relation)
      scope = apply_filters(scope)
      scope = apply_search(scope)
      apply_sort(scope)
    end

    delegate :name, to: :fieldset, prefix: true

    def filter_fields
      (structure.fieldset_filter_fields(fieldset) + @extra_fields.select(&:filterable?))
        .select { |f| f.permitted?(@permission) }
    end

    def sortable_fields
      (structure.fieldset_sortable_fields(fieldset) + @extra_fields.select(&:sortable?))
        .select { |f| f.permitted?(@permission) }
    end

    delegate :searchable?, to: :structure

    # Current value of a (logical, unprefixed) param — for filter controls.
    def value(key) = param(key)

    # The (prefixed) request-param names this query reads: every visible filter
    # field's value and `_geq`/`_leq` bounds, plus the reserved q/sort/dir. The
    # single source of truth for a strong-params permit list, so it can't drift
    # from the columns:
    #   params.permit(*query.permitted_keys)
    def permitted_keys
      (filter_param_keys + RESERVED_PARAMS).map { |key| param_name(key) }
    end

    # The subset of the current request params this query reads, present values
    # only, keyed by their real (prefixed) param names. Feed it to
    # filter-preserving links (pagers, breadcrumbs, "reset" targets) instead of
    # keeping a hand-maintained copy of the params.
    def filter_params
      permitted_keys.each_with_object({}) do |key, kept|
        raw = @params[key]
        kept[key] = raw if raw.is_a?(String) && raw.present?
      end
    end

    # The active filter and search values keyed by their logical (unprefixed)
    # name — for rendering active-filter chips. Range bounds appear as
    # `<field>_geq` / `<field>_leq`; the search box as `q`.
    def active_filters
      (filter_param_keys + ['q']).each_with_object({}) do |key, active|
        val = param(key)
        active[key] = val if val
      end
    end

    def active? = active_filters.any?

    # [field_name_string, direction_string] or nil.
    def sort_state
      field = current_sort_field
      field && [field.name.to_s, direction]
    end

    def param_name(key) = "#{prefix}#{key}"

    # The combobox suggestion request in `params`, if any, as
    # [requested name, field, typed term]. The field must be one this query
    # filters by (visible to the ability) and one that offers suggestions;
    # anything else yields a nil field, so an unknown or hidden name learns
    # nothing.
    def choices_request
      name = @params[param_name(CHOICES_PARAM)]
      return nil unless name.is_a?(String)

      field = filter_fields.find { |f| f.name.to_s == name && f.suggests_choices? }
      term = @params[param_name(TERM_PARAM)]
      [name, field, term.is_a?(String) ? term : '']
    end

    private

    # Logical (unprefixed) filter param keys: each visible filter field's value
    # plus its `_geq`/`_leq` bounds. Bounds are listed for every field even
    # though only ranges use them — apply_filters reads all three uniformly, so
    # the permit list mirrors exactly what can reach SQL.
    def filter_param_keys
      filter_fields.flat_map { |field| [field.name.to_s, "#{field.name}_geq", "#{field.name}_leq"] }
    end

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
        value = param(field.name.to_s)
        geq = param("#{field.name}_geq")
        leq = param("#{field.name}_leq")
        next current unless value || geq || leq

        field.apply_filter(current, value: value, geq: geq, leq: leq)
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
