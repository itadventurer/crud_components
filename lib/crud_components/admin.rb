require_relative 'admin/configuration'
require_relative 'admin/entry'
require_relative 'admin/registry'
require_relative 'admin/view_helpers'

module CrudComponents
  # The optional, mountable admin UI:
  #
  #   mount CrudComponents::Admin::Engine => '/admin'
  #
  # See docs/admin.md.
  module Admin
    class Error < CrudComponents::Error; end

    # Raised when a request reaches the engine before `authorize_with` (or the
    # explicit `allow_without_authentication!`) has been configured.
    class UnauthorizedError < Error; end

    # Raised when the ability denies the action behind the request. Rendered as
    # 403 by the engine's controllers.
    class ForbiddenError < Error; end

    class << self
      def config
        @config ||= Configuration.new
      end

      def configure
        yield config
        registry.reload!
        config
      end

      def registry
        @registry ||= Registry.new(config)
      end

      # Whether the engine actually drew this entry's routes. The registry can
      # resolve after the routes were drawn (a reload, a class defined later),
      # and a navigation entry without a route would only raise.
      def routed?(entry)
        return false unless defined?(Engine)

        Engine.routes.url_helpers.respond_to?("#{entry.route_key}_path")
      end

      # Drops both the configuration and the resolved registry.
      def reset!
        @config = nil
        @registry = nil
        @mount_path = nil
      end

      # Where the host mounted the engine, or nil when it did not.
      def mount_path
        return @mount_path if defined?(@mount_path) && !@mount_path.nil?
        return nil unless defined?(Engine) && defined?(Rails) && Rails.application

        route = Rails.application.routes.routes.find do |candidate|
          candidate.app.respond_to?(:app) && candidate.app.app == Engine
        end
        path = route&.path&.spec.to_s
        @mount_path = path == '/' ? '' : path.presence
      end

      # The admin's path for a record (or a model class, for its index), or nil
      # when the admin isn't mounted, the model isn't registered, or the action
      # is not enabled for it.
      def path_for(subject, action = :show)
        model = subject.is_a?(Class) ? subject : subject.class
        entry = registry[model]
        return nil unless entry&.allows?(action) && mount_path

        helper, args = helper_for(entry, action, subject)
        return nil unless Engine.routes.url_helpers.respond_to?(helper)

        Engine.routes.url_helpers.public_send(helper, *args, script_name: mount_path)
      end

      private

      def helper_for(entry, action, subject)
        case action.to_sym
        when :index then ["#{entry.route_key}_path", []]
        when :new   then ["new_#{entry.singular_route_key}_path", []]
        when :edit  then ["edit_#{entry.singular_route_key}_path", [subject]]
        else ["#{entry.singular_route_key}_path", [subject]]
        end
      end
    end
  end
end
