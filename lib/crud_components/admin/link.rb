# frozen_string_literal: true

module CrudComponents
  module Admin
    # A navigation entry that is not a model: a mounted dashboard, a report, any
    # page of the host application. Declared with {Configuration#link}; listed in
    # the sidebar and on the dashboard next to the models of its group.
    class Link
      attr_reader :key, :icon, :group, :path

      # @param label [String, Symbol] shown as is; a Symbol is translated under
      #   `crud_components.admin.links.<label>`.
      # @param path [String, Proc] a path, or a block run in the view (so
      #   `main_app.…_path` works); nil hides the link.
      # @param group [String, Symbol, nil] the sidebar group, as for models.
      # @param icon [String, nil] an icon name, without the library prefix.
      # @param condition [Proc, nil] run in the view; a falsy result hides the link.
      def initialize(label, path:, group: nil, icon: nil, condition: nil)
        validate!(label, path, condition)
        @key = label
        @path = path
        @group = group&.to_s
        @icon = icon&.to_s
        @condition = condition
      end

      def label
        return @key unless @key.is_a?(Symbol)

        I18n.t("crud_components.admin.links.#{@key}", default: @key.to_s.humanize)
      end

      def group_key = Entry.group_key(group)

      def group_label
        return nil unless group

        I18n.t("crud_components.admin.groups.#{group_key}", default: group)
      end

      def link? = true

      # This link as the view shows it — the path worked out — or nil when the
      # condition fails or no path resolves. A path block naming a route helper
      # this app does not have hides the link too.
      def resolve(view)
        return nil if @condition && !view.instance_exec(&@condition)

        resolved = @path.respond_to?(:call) ? view.instance_exec(&@path) : @path
        resolved && self.class.new(@key, path: resolved.to_s, group: @group, icon: @icon)
      rescue NameError => e
        raise unless e.name.to_s.end_with?('_path', '_url')

        nil
      end

      private

      def validate!(label, path, condition)
        raise ArgumentError, "link: label must be a String or Symbol, got #{label.inspect}" unless
          label.is_a?(String) || label.is_a?(Symbol)
        raise ArgumentError, "link #{label.inspect}: path: must be a String or a block, got #{path.inspect}" unless
          path.is_a?(String) || path.respond_to?(:call)
        return if condition.nil? || condition.respond_to?(:call)

        raise ArgumentError, "link #{label.inspect}: if: must be a block, got #{condition.inspect}"
      end
    end
  end
end
