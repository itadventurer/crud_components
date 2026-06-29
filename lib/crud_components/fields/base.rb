module CrudComponents
  module Fields
    # One subclass per field flavor (one row of the README's combination
    # table). A field knows how it renders (which partial), how it filters
    # (which control + how params reach SQL), and whether it sorts.
    #
    # Facets declared in an `attribute` block override exactly one of those:
    # :render (block), :filter (like-spec / block / false), :sort
    # (column symbol / block / false).
    class Base
      attr_reader :name, :model, :options, :facets

      def initialize(name, model, options = {}, facets = {})
        @name = name.to_sym
        @model = model
        @options = options
        @facets = facets
      end

      def human_name
        return options[:label] if options[:label].is_a?(String)

        model.human_attribute_name(name)
      end

      # ── column header (issue #4) ───────────────────────────────────────────
      # A column may own its `<th>`: a custom `header:` (a String rendered as-is —
      # mark it html_safe for markup — or a view-context block, e.g. a link), and
      # `header_actions:` — plain Action objects rendered in the header. A
      # `:selection` action there acts on the ticked rows (it submits the shared
      # select-form); any other action renders as a link/button. Available on every
      # field flavor: a DynamicColumn passes them through its options, a declared
      # `attribute` takes them as options too.
      def header = options[:header]
      def header_actions = Array(options[:header_actions])

      # Whether this column brings its own header markup or header actions — the
      # layout falls back to the plain human_name + sort link when it doesn't.
      def custom_header? = !header.nil? || header_actions.any?

      # Column-picker grouping: the heading this column sits under (a path
      # column groups under the association(s) it reaches through), or nil for an
      # own column. `picker_label` is the label shown within that group.
      def group_label = nil
      def picker_label = human_name

      # The model the column-picker groups this column under (Pipedrive-style):
      # its own model for a plain column, the *associated* model for an
      # association or path column — so `publisher`, `publisher.name` and
      # `publisher.founded_on` all sit under "Publisher".
      def group_model = model

      # The DB column backing this field, if any (nil for associations and
      # computed fields).
      def column
        model.columns_hash[name.to_s]
      end

      # How this field feeds the default ?q= ("search what you see"): its own
      # string/text column, or nil for fields with no free-text column behind
      # them (numbers, dates, enums, attachments, computed). Associations
      # override this to contribute their target's label.
      def search_spec_entry
        name if column && %i[string text].include?(column.type)
      end

      # Whether the backing column permits NULL — gates the "not set" filter
      # choice and the 3-state form control for nullable boolean/enum fields.
      def nullable?
        !!column&.null
      end

      # Whether this field's filter offers a "not set" (IS NULL) choice.
      def filter_includes_null?
        false
      end

      def value(record)
        record.public_send(name)
      end

      # ── rendering ────────────────────────────────────────────────────────
      def renderer(_record = nil)
        options[:as] || default_renderer
      end

      def default_renderer
        :string
      end

      def render_block
        facets[:render]
      end

      def renderer_options
        options.except(:as, :if, :form_as, :label, :header, :header_actions, :filter_as, :filter_choices)
      end

      # ── permissions ──────────────────────────────────────────────────────
      def permitted?(context, record = nil)
        Permission.permitted?(options[:if], model, context, record)
      end

      # ── filtering ────────────────────────────────────────────────────────
      def filterable?
        return false if facets[:filter] == false
        return false if CrudComponents::RESERVED_PARAMS.include?(name.to_s)
        return true if typed_filter || filter_facet

        derived_filterable?
      end

      def filter_facet
        facets[:filter].is_a?(Proc) || facets[:filter].is_a?(Array) ||
          facets[:filter].is_a?(Hash) || facets[:filter].is_a?(Symbol) ? facets[:filter] : nil
      end

      # The internal {TypedFilter} for a `filter:` block that declares keyword params
      # (eq:/geq:/leq:/contains:) — its value type comes from `filter_as:` or `as:`,
      # so it renders the matching control and receives cast values. A positional
      # `->(scope, value)` block has none (plain text filter); nil for everyone else.
      def typed_filter
        return @typed_filter if defined?(@typed_filter)

        @typed_filter = build_typed_filter
      end

      def derived_filterable?
        false
      end

      # Which filter control partial to render: :text, :select, :boolean,
      # :number_range or :date_range.
      def filter_control
        return typed_filter.control if typed_filter

        filter_facet ? :text : derived_filter_control
      end

      def derived_filter_control
        :text
      end

      def filter_choices(query = nil)
        typed_filter&.filter_choices(query)
      end

      def range_filter?
        filter_control == :number_range || filter_control == :date_range
      end

      # The raw param values (Strings or nil): `value` is the bare `?field=`, `geq`
      # and `leq` the range bounds. How a field reads `value` is up to it — an
      # exact match for a number/enum, a substring for text.
      def apply_filter(scope, value: nil, geq: nil, leq: nil)
        if typed_filter
          typed_filter.apply(scope, value:, geq:, leq:)
        elsif filter_facet
          return scope unless value

          apply_filter_facet(scope, value)
        else
          apply_derived_filter(scope, value:, geq:, leq:)
        end
      end

      def apply_filter_facet(scope, value)
        facet = filter_facet
        if facet.is_a?(Proc)
          facet.call(scope.extending(WhereLike), value)
        else
          LikeSpec.apply(scope, facet, value)
        end
      end

      def apply_derived_filter(scope, **)
        scope
      end

      # ── sorting ──────────────────────────────────────────────────────────
      def sortable?
        return false if facets[:sort] == false
        return false if CrudComponents::RESERVED_PARAMS.include?(name.to_s)
        return true if sort_facet

        derived_sortable?
      end

      def sort_facet
        facets[:sort].is_a?(Proc) || facets[:sort].is_a?(Symbol) ? facets[:sort] : nil
      end

      def derived_sortable?
        false
      end

      # An explicit `?sort=` must win over any order a prior stage set (a search
      # backend's relevance rank, a default scope). The Symbol/derived branches
      # already `.reorder`; a Proc facet is handed a scope whose prior order is
      # cleared, so a block using the obvious `.order(...)` overrides the rank too
      # rather than appending to it (see issue #23). A block may still `.reorder`
      # itself — that composes fine on an already-cleared scope.
      def apply_sort(scope, dir)
        case (facet = sort_facet)
        when Proc then facet.call(scope.reorder(nil), dir)
        when Symbol then scope.reorder(model.arel_table[facet].public_send(dir))
        else scope.reorder(model.arel_table[name].public_send(dir))
        end
      end

      # ── forms ──────────────────────────────────────────────────────────────
      # Columns that exist but are never user-editable in a derived form.
      NON_EDITABLE_COLUMNS = %w[id created_at updated_at].freeze

      # Whether this field appears as an *input* in a derived form. `editable:`
      # overrides; a symbol/Proc means "editable, subject to a can? check"
      # (see editable_permitted?).
      def editable?
        case options[:editable]
        when false then false
        when nil then default_editable?
        else true
        end
      end

      def default_editable?
        false
      end

      def editable_permitted?(context, record = nil)
        condition = options[:editable]
        return true unless condition.is_a?(Symbol) || condition.is_a?(Proc)

        # recordless: false — a record-dependent `editable:` can't be granted by
        # the class-level permit list (no record there); deny by default and let
        # the per-record form check decide where a record is present.
        Permission.permitted?(condition, model, context, record, recordless: false)
      end

      # The form-input flavor; nil = no form representation (json, computed).
      def form_control
        nil
      end

      # The form-input partial to render: crud_components/form_fields/_<name>.
      # Defaults to the field's form_control type; override per field with
      # `form_as:` (mirrors `as:` for the read-only/display renderer). The
      # partial receives the simple_form builder `f`, the `field`, and `form`.
      def form_partial
        options[:form_as] || form_control
      end

      # What this field contributes to a strong-params permit list — a symbol
      # or a nested hash; collected by Structure#permitted_params.
      def permit_param
        name
      end

      # ── loading ──────────────────────────────────────────────────────────
      # Includes-specs (symbols/nested hashes for ActiveRecord#includes) to
      # eager-load when this column is shown. Base contributes the per-attribute
      # `preload:` — associations a render block / custom renderer reaches on the
      # listed model. Association fields override to also nest the target's
      # identity_preloads under the association name.
      def eager_load
        declared_preloads
      end

      # The `preload:` option as an array of includes-specs (a nested hash kept
      # intact, unlike Array()).
      def declared_preloads
        case (p = options[:preload])
        when nil then []
        when Array then p
        else [p]
        end
      end

      private

      # Maps a render type (`as:` / `filter_as:`) to a filter value type. An
      # unmapped value (a custom renderer) falls back to text.
      RENDER_TO_FILTER_TYPE = {
        number: :numeric, numeric: :numeric,
        date: :date, datetime: :date,
        boolean: :boolean,
        enum: :select, select: :select,
        string: :text, text: :text
      }.freeze

      def build_typed_filter
        facet = facets[:filter]
        return facet if facet.is_a?(CrudComponents::TypedFilter)   # already built (escape hatch)
        return nil unless facet.is_a?(Proc) && keyword_filter_block?(facet)

        CrudComponents::TypedFilter.new(filter_type, facet, choices: options[:filter_choices])
      end

      # A filter block opts into a typed control by declaring keyword params
      # (eq:/geq:/leq:/contains:); a positional `->(scope, value)` stays plain text.
      def keyword_filter_block?(block)
        block.parameters.any? { |kind, _| %i[key keyreq keyrest].include?(kind) }
      end

      # The filter's value type: `filter_as:` if given, else inferred from the
      # render type `as:`, else text.
      def filter_type
        RENDER_TO_FILTER_TYPE.fetch(options[:filter_as] || options[:as], :text)
      end

      def arel_column
        model.arel_table[name]
      end

      def like_pattern(value)
        "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
      end
    end
  end
end
