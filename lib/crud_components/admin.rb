require_relative 'admin/configuration'
require_relative 'admin/entry'
require_relative 'admin/registry'

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

      # Drops both the configuration and the resolved registry.
      def reset!
        @config = nil
        @registry = nil
      end
    end
  end
end
