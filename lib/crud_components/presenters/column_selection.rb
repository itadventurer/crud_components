module CrudComponents
  module Presenters
    # Shared "which columns are shown" logic for any presenter that exposes
    # `available_fields` (the permitted universe) and a `param_prefix`. The
    # picker submits `?cols[]=` (or `?cols=a,b`); this reads it, falls back to the
    # `visible_columns:` default, and **always intersects with `available_fields`** — so a forged
    # or stale selection can only hide or reorder columns, never reveal one the
    # `if:` gate forbids. Mixed into both the collection and the record
    # presenter, so a column picker drives a table and a detail view alike.
    module ColumnSelection
      # The columns actually rendered: the permitted set, narrowed and ordered
      # by the user's selection when there is one.
      def fields
        @fields ||= select_visible(available_fields)
      end

      # Is this column part of the current view (ticked in the picker)?
      def column_visible?(field) = fields.include?(field)

      # The column-picker universe grouped by source model (Pipedrive-style):
      # `[[model, fields], …]` with this collection's own model first, then each
      # associated model in first-appearance order. So `publisher`,
      # `publisher.name` and `publisher.founded_on` cluster under Publisher.
      def field_groups
        by_model = available_fields.group_by(&:group_model)
        ordered = [model, *(by_model.keys - [model])]
        ordered.filter_map { |m| [m, by_model[m]] if by_model[m] }
      end

      # A picker group's heading text and icon (no prefix), for a grouped model.
      def group_heading(group_model) = group_model.model_name.human
      def group_icon(group_model) = Structure.for(group_model).icon

      # The ordered column names the user selected, or nil for "all permitted".
      # `?cols=` (a picker submit) wins over the `visible_columns:` server default.
      def visible_columns
        return @visible_columns if defined?(@visible_columns)

        @visible_columns = cols_param || @visible_override
      end

      private

      def select_visible(list)
        names = visible_columns
        return list unless names

        names.filter_map { |name| list.find { |field| field.name == name } }
      end

      # The picker submits `cols[]=a&cols[]=b` (no-JS) or, with the crud-columns
      # controller, a single comma-joined `cols=a,b` (prettier URL). Accept both.
      def cols_param
        raw = column_request_params[column_param_key]
        list = raw.is_a?(Array) ? raw : raw.is_a?(String) ? raw.split(',') : nil
        names = list&.map { |n| n.to_s.strip }&.reject(&:blank?)&.map(&:to_sym)
        names if names&.any?
      end

      def column_param_key = param_prefix ? "#{param_prefix}_cols" : 'cols'

      def column_request_params
        view.respond_to?(:request) && view.request ? view.request.query_parameters : {}
      end
    end
  end
end
