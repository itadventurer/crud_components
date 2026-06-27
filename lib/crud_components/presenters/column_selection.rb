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

      # The ordered column names to show, or nil for "all permitted". The selection
      # is independent of the gear: a resolved **Array** always applies (the backend
      # decided it — the gear may live elsewhere, e.g. a standalone picker or a
      # detail view), verbatim and without reading the param. `:auto` reads the
      # `?cols=` submit **only when a gear is rendered here** (`picker: true`); with
      # no gear here, `:auto` means "don't narrow" (a stray `?cols=` is ignored).
      def visible_columns
        return @visible_columns if defined?(@visible_columns)

        @visible_columns =
          if @picked_columns.is_a?(Array) then @picked_columns
          elsif @picker then cols_param
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
      # controller, a single comma-joined `cols=a,b` (prettier URL). Both forms are
      # parsed by {CrudComponents.selected_columns} (the same reader hosts use to
      # persist a pick) — we just symbolize the result. nil when nothing was picked.
      def cols_param
        CrudComponents.selected_columns(column_request_params, param_prefix: param_prefix)&.map(&:to_sym)
      end

      def column_request_params
        view.respond_to?(:request) && view.request ? view.request.query_parameters : {}
      end
    end
  end
end
