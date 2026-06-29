module CrudComponents
  module Fields
    # belongs_to / has_one: nil-safe link via the target's label. The filter
    # (belongs_to only) accepts both the target's identify_by value (what the
    # select submits) and free text matched against the target's label — the
    # name shown in the cell — one param, two OR-combined parameterized
    # subqueries.
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

      # Default ?q= reaches the target's label (the name shown in the cell).
      # Skipped for polymorphic (no single target) or a block/columnless label.
      def search_spec_entry
        name if !reflection.polymorphic? && target_structure.label_field_name
      end

      def derived_filterable?
        reflection.belongs_to? && !reflection.polymorphic?
      end

      # Sortable by the column behind the target's label — the name shown in the
      # cell — reached with a join. A block label, or a label that isn't a real
      # column, has no SQL ordering, so the column isn't sortable then.
      def derived_sortable? = sort_column.present?

      def apply_sort(scope, dir)
        return super if sort_facet

        scope.left_joins(name).reorder(target.arel_table[sort_column].public_send(dir))
      end

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

      def apply_derived_filter(scope, value: nil, **)
        return scope unless value

        identified = scope.where(name => target.where(target_structure.identify_by => value))
        searched = like_subquery(scope, value)
        searched ? identified.or(searched) : identified
      end

      # Load the association, nesting the target's identity_preloads (its label's
      # own association deps) plus any per-column `preload:` so the target's
      # label never N+1s. e.g. { order: %i[customer training] }.
      # A polymorphic belongs_to has no single target class, so we can't nest its
      # label's preloads — just preload the association itself (Rails groups it by
      # type); the cell still renders each record's label and links it at runtime.
      def eager_load
        return [name] if reflection.polymorphic?

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

      # The target column to ORDER BY: the field behind its label when that's a
      # real column, else nil (a block label or computed attribute can't be sorted
      # in SQL). Polymorphic belongs_to has no single target, so never sortable.
      def sort_column
        return nil if reflection.polymorphic?

        col = target_structure.label_field_name
        col if col && target.column_names.include?(col.to_s)
      end

      # Free text matches the target's label only — the name shown in the cell.
      # A block/computed label has no column to match, so there's no text filter.
      def like_subquery(scope, value)
        label = target_structure.label_field_name
        return nil unless label

        scope.where(name => LikeSpec.apply(target.all, [label], value))
      end
    end
  end
end
