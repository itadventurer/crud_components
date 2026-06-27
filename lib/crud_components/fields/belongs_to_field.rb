module CrudComponents
  module Fields
    # belongs_to / has_one: nil-safe link via the target's label. The filter
    # (belongs_to only) accepts both the target's identify_by value (what the
    # select submits) and free text matched against the target's search_in —
    # one param, two OR-combined parameterized subqueries.
    class BelongsToField < Base
      def default_renderer = :association

      def reflection
        @reflection ||= model.reflect_on_association(name)
      end

      def target
        reflection.klass
      end

      # Picker grouping: a belongs_to/has_one column anchors its target's group
      # (polymorphic has no single target, so it groups under its own model).
      def group_model = reflection.polymorphic? ? model : target

      def target_structure
        Structure.for(target)
      end

      def derived_filterable?
        reflection.belongs_to? && !reflection.polymorphic?
      end

      def derived_sortable? = false

      # select (a dropdown of all targets) below `select_limit` rows, else free
      # text. Counted per render, not memoized: the field instance lives on the
      # process-cached Structure, so a memoized count would freeze at its boot-time
      # value and render the wrong control once the table grows past the limit.
      # One COUNT per filter-row render is negligible next to rendering the table.
      def derived_filter_control
        target.count <= CrudComponents.config.select_limit ? :select : :text
      end

      def filter_choices(_query = nil)
        structure = target_structure
        target.all.map { |record| [structure.label_for(record).to_s, record.public_send(structure.identify_by)] }
              .sort_by(&:first)
      end

      def apply_derived_filter(scope, exact: nil, **)
        return scope unless exact

        identified = scope.where(name => target.where(target_structure.identify_by => exact))
        searched = like_subquery(scope, exact)
        searched ? identified.or(searched) : identified
      end

      # Load the association, nesting the target's identity_preloads (its label's
      # own association deps) plus any per-column `preload:` so the target's
      # label never N+1s. e.g. { order: %i[customer training] }.
      def eager_load
        nested = (target_structure.identity_preloads + declared_preloads).uniq
        [nested.empty? ? name : { name => nested }]
      end

      # ── forms ────────────────────────────────────────────────────────────
      # Assigned via the foreign key; the select submits real ids (forms are
      # POST bodies, not shareable URLs — unlike the filter, which uses
      # identify_by).
      def default_editable? = reflection.belongs_to? && !reflection.polymorphic?
      def form_control = :belongs_to
      def permit_param = reflection.foreign_key.to_sym

      def form_choices
        structure = target_structure
        target.all.map { |record| [structure.label_for(record).to_s, record.id] }.sort_by(&:first)
      end

      private

      def like_subquery(scope, value)
        spec = target_structure.search_in_spec
        return nil if spec.nil? || spec.empty?

        scope.where(name => LikeSpec.apply(target.all, spec, value))
      end
    end
  end
end
