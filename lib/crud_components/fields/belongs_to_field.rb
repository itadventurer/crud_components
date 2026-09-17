# frozen_string_literal: true

module CrudComponents
  module Fields
    # belongs_to / has_one: nil-safe link via the target's label. The filter
    # (belongs_to only) takes the identify_by values the value filter submits,
    # or a single string matched against the identify_by value and the
    # target's label — the name shown in the cell — as OR-combined
    # parameterized subqueries.
    class BelongsToField < Base
      include AssociationChoices

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
        name if !reflection.polymorphic? && target_structure.label_column_name
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

      # A value filter: a multiple select (checkboxes in a popover with the
      # crud-value-filter controller) of the targets occurring in the list.
      def derived_filter_control = :values

      # [label, identify_by] pairs: the targets the ability may see that occur
      # in the query's base scope — the rows the list could show before any
      # filter, so picking one never shrinks the choice to itself.
      def filter_choices(query = nil)
        choice_records(query&.ability, within: occurring_in(query)).map { |_, record| choice_pair(record) }
      end

      # Only the derived filter takes several values and answers searches; a
      # `filter` block or typed filter reads a single string.
      def suggests_choices? = derived_filterable? && !typed_filter && !filter_facet
      def multi_value_filter? = suggests_choices?

      def nullable? = !!model.columns_hash[reflection.foreign_key.to_s]&.null
      def filter_includes_null? = nullable?

      # Up to `limit` [label, identify_by] pairs out of #filter_choices whose
      # label contains `term` (the free-text match), plus the `selected` values
      # beyond that limit, and how many choices match in all.
      def filter_values(query, term: '', selected: [], limit: CrudComponents.config.value_filter_inline_limit)
        records = filter_choice_scope(query)
        found, total = matching(records, term, limit)
        pairs = found.map { |record| choice_pair(record) }
        missing = selected.map(&:to_s) - pairs.map { |_, value| value.to_s }
        pairs += selected_records(records, missing).map { |record| choice_pair(record) } if missing.any?
        [pairs.sort_by(&:first), total]
      end

      # A single string (`?publisher=tor`) matches the identify_by value or the
      # label; an array (`?publisher[]=tor&publisher[]=ace`) matches the
      # identify_by values exactly. NULL_FILTER_VALUE among them adds IS NULL.
      def apply_derived_filter(scope, value: nil, **)
        values = Array(value).map(&:to_s).compact_blank
        return scope if values.empty?

        blank = values.delete(CrudComponents::NULL_FILTER_VALUE)
        parts = []
        if values.any?
          parts << scope.where(name => target.where(target_structure.identify_by => values))
          parts << like_subquery(scope, value) if value.is_a?(String)
        end
        parts << scope.where(reflection.foreign_key => nil) if blank
        parts.compact.reduce(:or)
      end

      # Load the association, nesting the target's identity_preloads (its label's
      # own association deps) plus any per-column `preload:` so the target's
      # label never N+1s. e.g. { book: %i[publisher authors] }.
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
      def default_form_control = :belongs_to
      def permit_param = reflection.foreign_key.to_sym

      private

      def choice_pair(record)
        [target_structure.label_for(record).to_s, record.public_send(target_structure.identify_by)]
      end

      def filter_choice_scope(query)
        choice_scope(query&.ability, within: occurring_in(query))
      end

      # A where-condition on the target: its key is among the foreign keys of
      # the query's base scope. Ordering and pagination of the base don't
      # matter to which targets occur, so they are dropped.
      def occurring_in(query)
        base = query&.base_scope
        return nil unless base

        keys = base.unscope(:order, :limit, :offset).reselect(base.klass.arel_table[reflection.foreign_key])
        { reflection.association_primary_key => keys }
      end

      # [the first `limit` records whose label contains `term`, their total].
      # A label block has no column to match in SQL, so the labels are matched
      # in Ruby.
      def matching(records, term, limit)
        label = target_structure.label_column_name
        if records.is_a?(ActiveRecord::Relation) && label
          records = LikeSpec.apply(records, [label], term) if term.present?
          return [records.reorder(target.arel_table[label]).limit(limit).to_a, records.count]
        end

        needle = term.to_s.downcase
        found = records.to_a
                       .map { |record| [target_structure.label_for(record).to_s, record] }
                       .select { |text, _| text.downcase.include?(needle) }
                       .sort_by(&:first)
        [found.first(limit).map(&:last), found.size]
      end

      def selected_records(records, values)
        identify_by = target_structure.identify_by
        return records.where(identify_by => values).to_a if records.is_a?(ActiveRecord::Relation)

        records.select { |record| values.include?(record.public_send(identify_by).to_s) }
      end

      # The target column to ORDER BY: the field behind its label when that's a
      # real column, else nil (a block label or computed attribute can't be sorted
      # in SQL). Polymorphic belongs_to has no single target, so never sortable.
      def sort_column
        return nil if reflection.polymorphic?

        target_structure.label_column_name
      end

      # Free text matches the target's label only — the name shown in the cell.
      # A block/computed label has no column to match, so there's no text filter.
      def like_subquery(scope, value)
        label = target_structure.label_column_name
        return nil unless label

        scope.where(name => LikeSpec.apply(target.all, [label], value))
      end
    end
  end
end
