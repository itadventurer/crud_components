module CrudComponents
  module Presenters
    # Shared "which columns are shown" logic for any presenter that exposes
    # `available_fields` (the permitted universe) and a `param_prefix`. Two knobs
    # drive it (set as `@picker` and `@picked_columns` by the including presenter):
    #
    #   @picker         false → no picking (the fieldset governs); true → the view
    #                   participates (a collection also renders the gear).
    #   @picked_columns :auto → read the `?cols=` submit; an Array → that exact
    #                   selection, **without ever reading the param** (the backend
    #                   already resolved it — from a persisted pref, or from the
    #                   param via {CrudComponents.selected_columns}).
    #
    # The chosen selection is **always intersected with `available_fields`** — so a
    # forged or stale selection can only hide or reorder columns, never reveal one
    # the `if:` gate forbids. Mixed into both the collection and the record
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

      # The ordered column names to show, or nil for "all permitted". Picking off
      # → nil. A resolved Array → verbatim (no param read). `:auto` → the `?cols=`
      # submit (nil when absent, i.e. show all until the user picks).
      def visible_columns
        return @visible_columns if defined?(@visible_columns)

        @visible_columns =
          if !@picker then nil
          elsif @picked_columns.is_a?(Array) then @picked_columns
          else cols_param
          end
      end

      private

      # Normalize the `picked_columns:` knob: `:auto`/nil → `:auto`; an Array →
      # its symbols. Anything else is a mistake worth catching at the call site.
      def normalize_picked_columns(value)
        case value
        when :auto, nil then :auto
        when Array then value.map(&:to_sym)
        else
          raise ArgumentError,
                "picked_columns: expects :auto or an Array of column names, got #{value.inspect}"
        end
      end

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
