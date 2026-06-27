module CrudComponents
  module Fields
    # A column that reaches *through* associations: a dotted name like
    # `publisher.name` or `authors.email`. The leading segments are associations
    # on the model; the last is an attribute (or method) on the target.
    #
    # A single-valued path (belongs_to / has_one) **delegates to the target
    # model's own field** for that attribute: `publisher.founded_on` renders,
    # filters and sorts exactly like Publisher's `founded_on` column does — a date
    # cell, a date-range filter, an ORDER BY the date — and `publisher.price` keeps
    # the target's `unit:`/`digits:` formatting. The path column can still override
    # any of it (`as:`, a `filter`/`sort`/`render` facet, or its own options) —
    # **override > target field > default**. A collection path (has_many / habtm)
    # renders the values as a list and filters by contains-match through the join.
    # The association is eager-loaded automatically.
    #
    # When the leaf attribute *is* the target's label field (`publisher.name`),
    # the cell renders a link to that record — its model icon then a link to its
    # show page — so a path column doubles as a jump-to-the-object.
    #
    # Two limits (see #validate!): the chain may be at most `config.max_path_depth`
    # associations deep, and it may cross **at most one to-many** association —
    # belongs_to/has_one chain freely, but a second has_many/habtm would fan a
    # list out into a meaningless list-of-lists. `habtm → one` (authors.publisher.name)
    # is fine; `habtm → many` is not.
    class PathField < ComputedField
      # Target field flavors a single-valued path delegates render/filter/sort to.
      # belongs_to/has_one/attachment/json/computed targets keep the path's own
      # value-type rendering and contains-match filtering (no delegation).
      SCALAR_TARGETS = [StringField, TextField, NumericField, DateField,
                        BooleanField, EnumField].freeze

      def initialize(name, model, options = {}, facets = {})
        super
        @segments = name.to_s.split('.').map(&:to_sym)
        validate!
      end

      # The list of values reached by the path: an Array for a collection path,
      # the single value (or nil) otherwise.
      def value(record)
        values = leaf_values(record)
        collection? ? values : values.first
      end

      # Single value: the target field's renderer (date/number/email/…) when it's
      # a scalar column — so the path renders like the target — unless overridden.
      # Collection / non-scalar target: fall back to the inferred value-type
      # renderer (ComputedField).
      def renderer(record = nil)
        return options[:as] if options[:as]
        return nil if render_block

        return target_field.renderer if delegating?

        super
      end

      # Target-field options (unit/digits/…) as the base, overridden by any the
      # path column declares itself — `override > target field`.
      def renderer_options
        own = super
        delegating? ? target_field.renderer_options.merge(own) : own
      end

      # Single paths render through the renderer; collection paths render as a
      # joined list, and a path to the target's label field renders a link.
      def render_block
        return facets[:render] if facets[:render]
        return list_renderer if collection?
        return label_link_renderer if link_to_target?

        nil
      end

      # @api private — runs in the view context (`view`), via the render block.
      def render_list(view, record)
        items = Array(value(record)).map { |v| v.to_s.strip }.reject(&:blank?)
        return view.tag.span('—', class: CrudComponents.config.css.muted) if items.empty?

        # ask the target's field how it renders (email → mailto, url → link)
        semantic = target_field&.renderer
        view.safe_join(items.map { |item| link_value(view, semantic, item) }, ', ')
      end

      # @api private — the label-field link (model icon + link to the record's
      # show page), runs in the view context via the render block.
      def render_list_label(view, record)
        target = target_record(record)
        muted = CrudComponents.config.css.muted
        return view.tag.span('—', class: muted) if target.nil?

        label = value(record).to_s
        icon = view.crud_model_icon(target_model)
        inner = view.safe_join([icon, view.tag.span(label)].compact, icon ? ' ' : '')
        path = view.crud_record_path(target)
        path ? view.link_to(inner, path, data: { turbo_action: 'advance' }) : inner
      end

      # Header: a breadcrumb "Parent › Attribute" (Pipedrive-style). The picker
      # groups by `group_label` and shows the short `picker_label`, so it isn't
      # repeated there.
      def human_name
        return options[:label] if options[:label].is_a?(String)

        "#{group_label} › #{picker_label}"
      end

      def group_label
        reflections.map { |ref| ref.active_record.human_attribute_name(ref.name) }.join(' › ')
      end

      def picker_label = target_model.human_attribute_name(attribute_name)

      # Picker grouping: a path column sits under its target model's group, next
      # to the association column that anchors it.
      def group_model = target_model

      # Eager-load the association chain so a whole page costs one query, not one
      # per row (e.g. `publisher.founded_on` → includes(:publisher)).
      def eager_load
        spec = assoc_segments.reverse.reduce(nil) { |inner, seg| inner ? { seg => inner } : seg }
        spec ? [spec] : []
      end

      # ── filtering ─────────────────────────────────────────────────────────────
      # Single-valued scalar paths offer the target field's own control (a date
      # range, an enum select, …) and apply it through the association; collection
      # / non-scalar paths keep the safe contains-match.
      def filterable? = facets[:filter] != false

      def filter_control
        return :text if filter_facet
        delegating? ? target_field.filter_control : :text
      end

      def filter_choices(query = nil)
        return nil unless delegating? && !filter_facet

        target_field.filter_choices(query)
      end

      def filter_includes_null?
        delegating? && !filter_facet ? target_field.filter_includes_null? : false
      end

      def nullable?
        delegating? ? target_field.nullable? : super
      end

      # The target field humanizes its own values (enum labels); a path delegates
      # so a `publisher.status` cell badges the same text the Publisher table does.
      def human_value(value)
        delegating? && target_field.respond_to?(:human_value) ? target_field.human_value(value) : value
      end

      def apply_filter(scope, exact: nil, geq: nil, leq: nil)
        return super if filter_facet      # an author-supplied facet wins
        return delegate_filter(scope, exact: exact, geq: geq, leq: leq) if delegating?
        return scope unless exact

        LikeSpec.apply(scope, filter_spec, exact)
      end

      # ── sorting: single-valued paths only ────────────────────────────────────
      def sortable? = !collection? && facets[:sort] != false

      def apply_sort(scope, dir)
        return super if sort_facet

        joins = eager_load.first
        scope = scope.left_joins(joins) if joins
        scope.reorder(target_model.arel_table[attribute_name].public_send(dir))
      end

      def collection? = reflections.any?(&:collection?)
      def single? = !collection?

      private

      def assoc_segments = @segments[0..-2]
      def attribute_name = @segments.last

      def reflections
        @reflections ||= begin
          klass = model
          assoc_segments.map do |seg|
            ref = klass.reflect_on_association(seg)
            klass = ref.klass
            ref
          end
        end
      end

      def target_model = reflections.last.klass

      # The target model's own field for the leaf attribute — what a single-valued
      # path delegates to. nil when the attribute isn't a real field (a bare
      # method): then the path keeps its value-type rendering / contains filter.
      def target_field
        return @target_field if defined?(@target_field)

        @target_field = Structure.for(target_model).field(attribute_name)
      rescue DefinitionError
        @target_field = nil
      end

      # Delegate render/filter/sort to the target field when the path is
      # single-valued and the target is a scalar column field (not an association,
      # attachment, json or computed method).
      def delegating?
        single? && (tf = target_field) && SCALAR_TARGETS.any? { |k| tf.is_a?(k) }
      end

      # A single-valued path whose leaf attribute *is* the target's label field —
      # rendered as a link to that record.
      def link_to_target?
        single? && !options[:as] && !facets[:render] &&
          Structure.for(target_model).label_field_name == attribute_name
      end

      # Apply the target field's own filter through the association: filter the
      # target model on its own table (so `where(col => …)` binds correctly), then
      # constrain the root through the association chain — an IN subquery, no JOIN,
      # so it can't multiply rows.
      def delegate_filter(scope, exact:, geq:, leq:)
        matched = target_field.apply_filter(target_model.all, exact: exact, geq: geq, leq: leq)
        constrained = reflections.reverse.reduce(matched) do |sub, ref|
          ref.active_record.where(ref.name => sub)
        end
        scope.where(model.primary_key => constrained)
      end

      # Walk the path, following each segment over every object reached so far;
      # association collections fan out and flatten. Nils drop.
      def leaf_values(record)
        @segments.reduce([record]) do |objects, seg|
          objects.flat_map do |object|
            next [] if object.nil?

            value = object.public_send(seg)
            value.is_a?(Enumerable) ? value.to_a : [value]
          end
        end.compact
      end

      # The associated record a single-valued path reaches (book → book.publisher),
      # or nil when any hop is nil. Used by the label-field link.
      def target_record(record)
        assoc_segments.reduce(record) do |object, seg|
          break nil if object.nil?

          object.public_send(seg)
        end
      end

      # The like-spec the path describes, e.g. [:authors, :email] → { authors: :email }.
      def filter_spec
        assoc_segments.reverse.reduce(attribute_name) { |inner, seg| { seg => inner } }
      end

      def list_renderer
        field = self
        # `self` inside the block is the view (instance_exec'd by render_cell).
        proc { |record| field.render_list(self, record) }
      end

      def label_link_renderer
        field = self
        proc { |record| field.render_list_label(self, record) }
      end

      # One list item as a link (mailto / http) when the target name calls for
      # it, else a plain (escaped-on-join) value.
      def link_value(view, semantic, value)
        case semantic
        when :email then view.mail_to(value)
        when :url   then value.match?(%r{\Ahttps?://}i) ? view.link_to(value, value, rel: 'noopener', target: '_blank') : value
        else value
        end
      end

      def validate!
        klass = model
        to_many = 0
        assoc_segments.each do |seg|
          ref = klass.reflect_on_association(seg)
          unless ref
            raise DefinitionError,
                  "#{model}: '#{name}' is not a valid column path — '#{seg}' is not an " \
                  "association on #{klass}. A path column is association(s) then an attribute, " \
                  'e.g. publisher.name or authors.email.'
          end
          to_many += 1 if ref.collection?
          klass = ref.klass
        end

        max = CrudComponents.config.max_path_depth
        if assoc_segments.size > max
          raise DefinitionError,
                "#{model}: column path '#{name}' chains #{assoc_segments.size} associations; the " \
                "limit is #{max} (config.max_path_depth — raise it if you need deeper paths)."
        end

        # Chaining belongs_to/has_one is cheap and single-valued; a second
        # to-many hop would fan a list out into a list-of-lists with no sensible
        # flat rendering, sort or filter. One to-many (incl. habtm→one) is fine.
        return unless to_many > 1

        raise DefinitionError,
              "#{model}: column path '#{name}' crosses #{to_many} to-many associations. At most one " \
              'has_many/habtm hop is allowed — chain belongs_to/has_one freely, but a to-many may ' \
              'appear only once (e.g. authors.email, or authors.publisher.name).'
      end
    end
  end
end
