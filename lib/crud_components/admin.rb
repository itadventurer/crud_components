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
      end
    end
  end
end
