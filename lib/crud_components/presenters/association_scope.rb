# frozen_string_literal: true

module CrudComponents
  module Presenters
    # Narrows has_many / habtm cells to the records the ability may see. The
    # association stays preloaded as a whole (a preload cannot take a scope);
    # per field, one query asks which of the loaded ids `accessible_by` keeps,
    # for all rows at once, and the cells filter in memory. Nothing is written
    # back to the association, so the records themselves stay untouched.
    class AssociationScope
      # @param ability the ability to scope by, or nil (no scoping)
      # @param rows [#call] returns the records the presenter renders, or nil
      def initialize(ability, rows)
        @ability = ability
        @rows = rows
        @visible = {}
      end

      # The field's value for `record`, reduced to what the ability may see.
      def value(field, record)
        items = field.value(record)
        return items unless applies?(field)

        keep = visible_ids(field, record)
        key = field.target.primary_key
        items.to_a.select { |item| keep.include?(item[key]) }
      end

      private

      def applies?(field)
        field.is_a?(Fields::HasManyField) && field.scope_by_ability? &&
          @ability.respond_to?(:model_adapter) && field.target.respond_to?(:accessible_by)
      end

      def visible_ids(field, record)
        rows = @rows.call
        cache_key = rows ? field.name : [field.name, record]
        @visible[cache_key] ||= begin
          key = field.target.primary_key
          ids = (rows || [record]).flat_map { |row| field.value(row).to_a.map { |item| item[key] } }.uniq
          if ids.empty?
            Set.new
          else
            Permission.accessible(field.target.where(key => ids), @ability).pluck(key).to_set
          end
        end
      end
    end
  end
end
