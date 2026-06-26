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

      # Where the gem's own field partials live — used to tell a host override
      # apart from the shipped partial (so the fast path only skips the latter).
      GEM_VIEW_ROOT = File.expand_path('../../../app/views', __dir__).freeze

      # Renders one field value: the render block (in view context, record as
      # argument), a fast inline renderer (built-in types, no host override), or
      # the renderer partial `crud_components/fields/_<name>`. `cell_context`
      # (a CellContext or nil) lets value renderers build click-to-filter links;
      # it is nil on surfaces without a query.
      def render_cell(field, record, surface:, cell_context: nil)
        # The render block gets the record *and* the field's value — so a block on
        # a DynamicColumn can read its `preload:`-ed value without an `as:` partial.
        # Extra arg is harmless for one-arg blocks/procs (Proc ignores surplus args).
        return view.instance_exec(record, field.value(record), &field.render_block) if field.render_block

        renderer = field.renderer(record) || :string
        locals = { value: field.value(record), record: record, field: field,
                   surface: surface, cell_context: cell_context }
        if fast_cell?(renderer)
          cells.render(renderer, **locals)
        else
          view.render("crud_components/fields/#{renderer}", **locals)
        end
      end

      # Renders one filter control partial `crud_components/filters/_<control>`.
      def render_filter_control(field, query, form_id: nil, compact: false, autosubmit: false)
        view.render("crud_components/filters/#{field.filter_control}",
                    field: field, query: query, form_id: form_id, compact: compact,
                    autosubmit: autosubmit, param_name: query.param_name(field.name.to_s),
                    css: css)
      end

      private

      def cells
        @cells ||= Cells.new(view)
      end

      # Fast inline path only for built-in renderers the host hasn't overridden.
      def fast_cell?(renderer)
        config.fast_cells && Cells.handles?(renderer) && !host_overrides_field_partial?(renderer)
      end

      # Does the resolved fields/_<renderer> partial come from the host app
      # rather than the gem? Memoized per presenter (one table = one instance).
      def host_overrides_field_partial?(renderer)
        (@field_partial_override ||= {}).fetch(renderer) do
          @field_partial_override[renderer] =
            begin
              template = view.lookup_context.find(renderer.to_s, ['crud_components/fields'], true)
              !template.identifier.to_s.start_with?(GEM_VIEW_ROOT)
            rescue StandardError
              true # can't tell → use the (overridable) partial, never wrong output
            end
        end
      end
    end
  end
end
