module CrudComponents
  module Fields
    # has_many / habtm: truncated list of links ("a, b +3 more"). Filters by
    # present / absent out of the box (#apply_presence_filter, via the EXISTS the
    # collection implies); opt into a value match instead with `filter like: :assoc`
    # — a `filter` facet takes precedence over the derived presence control. No
    # derived sort.
    class HasManyField < Base
      include PresenceFilter

      def default_renderer = :association_list

      def reflection
        @reflection ||= model.reflect_on_association(name)
      end

      def target
        reflection.klass
      end

      # Picker grouping: a has_many/habtm column anchors its target's group, so
      # `authors`, `authors.name` and `authors.email` all sit under "Author".
      def group_model = target

      # Load the association, nesting each target's identity_preloads (+ this
      # column's `preload:`) so rendering the list's labels never N+1s.
      def eager_load
        nested = (target_structure.identity_preloads + declared_preloads).uniq
        [nested.empty? ? name : { name => nested }]
      end

      # The index a "+n more" / list link points at: the nested route under
      # the owner if it resolves, else the target's index filtered by the
      # owner. Resolved in the view (RouteResolver); here we just expose the
      # association so the renderer can build it.
      def collection_link_target = target

      # ── forms ────────────────────────────────────────────────────────────
      # Editable only for habtm (and simple has_many) via the *_ids setter —
      # reassigning ids is safe; nested attributes are out of scope.
      def habtm? = reflection.macro == :has_and_belongs_to_many
      def default_editable? = habtm?
      def form_control = :habtm
      def ids_method = "#{name.to_s.singularize}_ids".to_sym
      def permit_param = { ids_method => [] }

      def form_choices
        structure = target_structure
        target.all.map { |record| [structure.label_for(record).to_s, record.id] }.sort_by(&:first)
      end

      def target_structure = Structure.for(target)

      # Default ?q= reaches the children's label (the names shown in the list).
      # Skipped when the target's label is a block/columnless.
      def search_spec_entry
        name if target_structure.label_field_name
      end
    end
  end
end
