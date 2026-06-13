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
        model.human_attribute_name(name)
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
        options.except(:as, :if)
      end

      # ── permissions ──────────────────────────────────────────────────────
      def permitted?(context, record = nil)
        Permission.permitted?(options[:if], model, context, record)
      end

      # ── filtering ────────────────────────────────────────────────────────
      def filterable?
        return false if facets[:filter] == false
        return false if CrudComponents::RESERVED_PARAMS.include?(name.to_s)
        return true if filter_facet

        derived_filterable?
      end

      def filter_facet
        facets[:filter].is_a?(Proc) || facets[:filter].is_a?(Array) ||
          facets[:filter].is_a?(Hash) || facets[:filter].is_a?(Symbol) ? facets[:filter] : nil
      end

      def derived_filterable?
        false
      end

      # Which filter control partial to render: :text, :select, :boolean,
      # :number_range or :date_range.
      def filter_control
        filter_facet ? :text : derived_filter_control
      end

      def derived_filter_control
        :text
      end

      def filter_choices(_query = nil)
        nil
      end

      def range_filter?
        filter_control == :number_range || filter_control == :date_range
      end

      # `exact`, `geq`, `leq` are the raw param values (Strings or nil).
      def apply_filter(scope, exact: nil, geq: nil, leq: nil)
        if filter_facet
          return scope unless exact

          apply_filter_facet(scope, exact)
        else
          apply_derived_filter(scope, exact:, geq:, leq:)
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

      def apply_sort(scope, dir)
        case (facet = sort_facet)
        when Proc then facet.call(scope, dir)
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

        Permission.permitted?(condition, model, context, record)
      end

      # The form control partial (crud_components/forms/_<name>); nil = the
      # field cannot be edited (rendered read-only instead).
      def form_control
        nil
      end

      # What this field contributes to a strong-params permit list — a symbol
      # or a nested hash; collected by Structure#permitted_params.
      def permit_param
        name
      end

      # ── loading ──────────────────────────────────────────────────────────
      # Association to eager-load when this field is visible.
      def eager_load_name
        nil
      end

      private

      def arel_column
        model.arel_table[name]
      end

      def like_pattern(value)
        "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
      end
    end
  end
end
