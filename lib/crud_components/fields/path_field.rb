module CrudComponents
  module Fields
    # A column that reaches *through* associations: a dotted name like
    # `publisher.name` or `authors.email`. The leading segments are associations
    # on the model; the last is an attribute (or method) on the target.
    #
    # A single-valued path (belongs_to / has_one) renders like the target column
    # — `publisher.founded_on` formats as a date. A collection path
    # (has_many / habtm) renders the values as a list — `authors.email` shows
    # every author's email. The association is eager-loaded automatically.
    #
    # Filtering reuses the search mini-language (`{ authors: :email }`), so it
    # joins and parameterizes safely. Sorting works for single-valued paths
    # (a LEFT JOIN + ORDER BY the target column); a collection path isn't
    # sortable (no single value to order by) unless you give it a `sort` facet.
    #
    # Two limits (see #validate!): the chain may be at most `config.max_path_depth`
    # associations deep, and it may cross **at most one to-many** association —
    # belongs_to/has_one chain freely, but a second has_many/habtm would fan a
    # list out into a meaningless list-of-lists. `habtm → one` (authors.publisher.name)
    # is fine; `habtm → many` is not.
    class PathField < ComputedField
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

      # Single value: render through the inferred renderer (date/number/…) like a
      # computed field, but honor the name-gated smart renderers too (a target
      # column named `email`/`url` → a link). Collection: the list render block.
      def renderer(record = nil)
        return options[:as] if options[:as]
        return nil if render_block

        SemanticRenderer.renderer_for(attribute_name) || super
      end

      # Single paths render through the renderer; collection paths render as a
      # joined list via this block (linkifying emails/urls per the target name).
      def render_block
        facets[:render] || (collection? ? list_renderer : nil)
      end

      # @api private — runs in the view context (`view`), via the render block.
      def render_list(view, record)
        items = Array(value(record)).map { |v| v.to_s.strip }.reject(&:blank?)
        return view.tag.span('—', class: CrudComponents.config.css.muted) if items.empty?

        semantic = SemanticRenderer.renderer_for(attribute_name)
        view.safe_join(items.map { |item| link_value(view, semantic, item) }, ', ')
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

      # Eager-load the association chain so a whole page costs one query, not one
      # per row (e.g. `publisher.founded_on` → includes(:publisher)).
      def eager_load
        spec = assoc_segments.reverse.reduce(nil) { |inner, seg| inner ? { seg => inner } : seg }
        spec ? [spec] : []
      end

      # ── filtering: contains-match through the association (safe, joined) ──────
      def filterable? = facets[:filter] != false

      def apply_filter(scope, exact: nil, geq: nil, leq: nil)
        return super if filter_facet      # an author-supplied facet wins
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

      # The like-spec the path describes, e.g. [:authors, :email] → { authors: :email }.
      def filter_spec
        assoc_segments.reverse.reduce(attribute_name) { |inner, seg| { seg => inner } }
      end

      def list_renderer
        field = self
        # `self` inside the block is the view (instance_exec'd by render_cell).
        proc { |record| field.render_list(self, record) }
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
