module CrudComponents
  module Presenters
    # Presenters are the single local each partial receives — they hold the
    # logic so the templates stay dumb markup.
    class Base
      attr_reader :view

      def initialize(view:)
        @view = view
      end

      def config = CrudComponents.config
      def css = config.css

      # can?-shaped context for `if:` checks; the view itself when CanCanCan
      # (or anything can?-shaped) is around.
      def permission_context
        @permission_context ||= view.respond_to?(:can?) ? view : PermissionContext.new(nil)
      end

      # An ability object for Query (auto mode).
      def ability
        if view.respond_to?(:current_ability)
          view.current_ability
        elsif view.respond_to?(:can?)
          ViewAbility.new(view)
        end
      end

      class ViewAbility
        def initialize(view) = @view = view

        def can?(action, subject) = @view.can?(action, subject)
      end

      # Renders one field value: the render block (in view context, record as
      # argument) or the renderer partial `crud_components/fields/_<name>`.
      # `cell_context` (a CellContext or nil) lets value renderers build
      # click-to-filter links; it is nil on surfaces without a query.
      def render_cell(field, record, surface:, cell_context: nil)
        if field.render_block
          view.instance_exec(record, &field.render_block)
        else
          renderer = field.renderer(record) || :string
          view.render("crud_components/fields/#{renderer}",
                      value: field.value(record), record: record, field: field,
                      surface: surface, cell_context: cell_context)
        end
      end

      # Renders one filter control partial `crud_components/filters/_<control>`.
      def render_filter_control(field, query, form_id: nil, compact: false, autosubmit: false)
        view.render("crud_components/filters/#{field.filter_control}",
                    field: field, query: query, form_id: form_id, compact: compact,
                    autosubmit: autosubmit, param_name: query.param_name(field.name.to_s),
                    css: css)
      end
    end
  end
end
