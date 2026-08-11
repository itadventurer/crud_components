module CrudComponents
  module Admin
    # What the mounted admin needs to know that the models don't say themselves.
    #
    #   CrudComponents::Admin.configure do |config|
    #     config.authorize_with { head :forbidden unless current_user&.admin? }
    #     config.title = 'Bookstore admin'
    #   end
    class Configuration
      # Model name prefixes that are framework bookkeeping, not application data.
      DEFAULT_EXCLUDED_NAMESPACES = %w[
        ActiveRecord ActiveStorage ActionText ActionMailbox
        SolidQueue SolidCache SolidCable
        Delayed GoodJob Que Noticed PgSearch
      ].freeze

      # Bootstrap 5 + Bootstrap Icons, what the bundled layout's markup expects.
      DEFAULT_STYLESHEETS = [
        'https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css',
        'https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css'
      ].freeze

      # Sidebar brand line; defaults to the application's name.
      attr_accessor :title

      # The layout the engine renders in. 'crud_components/admin' is the bundled
      # Bootstrap shell; name one of your own (e.g. 'application') instead.
      attr_accessor :layout

      # nil = every discovered model. An Array of model names (String, Symbol or
      # class) means exactly those, in that order, discovery filters bypassed.
      attr_accessor :only

      # Model names to drop from an otherwise automatic registry.
      attr_accessor :except

      # Sidebar group order. Groups not listed follow, alphabetically.
      attr_accessor :groups

      # Model name prefixes to skip during discovery.
      attr_accessor :excluded_namespaces

      # Whether the dashboard runs a COUNT(*) per model.
      attr_accessor :counts

      # The controller the engine's own controllers inherit from — how the admin
      # reaches your `current_user`, your session and your `rescue_from`s.
      attr_accessor :parent_controller

      # Rows per index page, when a pagination gem is present.
      attr_accessor :per_page

      # Stylesheet URLs the bundled layout loads. Irrelevant when `layout` names
      # a layout of your own.
      attr_accessor :stylesheets

      # The `before_action` body that decides who gets in. See {#authorize_with}.
      attr_reader :authorize_block

      def initialize
        @title = nil
        @layout = 'crud_components/admin'
        @only = nil
        @except = []
        @groups = []
        @excluded_namespaces = DEFAULT_EXCLUDED_NAMESPACES.dup
        @counts = true
        @parent_controller = '::ApplicationController'
        @per_page = 50
        @stylesheets = DEFAULT_STYLESHEETS.dup
        @authorize_block = nil
        @allow_without_authentication = false
      end

      # The resolved parent controller class, falling back to ActionController::Base
      # when the named one does not exist.
      def parent_controller_class
        @parent_controller.to_s.safe_constantize || ActionController::Base
      end

      # The gate. Runs as a `before_action` in the engine's controller, in that
      # controller's own context — `current_user`, `redirect_to`, `head` and
      # your `rescue_from`s all work as usual.
      #
      #   config.authorize_with { redirect_to main_app.root_path unless current_user&.admin? }
      def authorize_with(&block)
        raise ArgumentError, 'authorize_with requires a block' unless block

        @authorize_block = block
      end

      # Serve the admin with no gate at all — a public demo, a local playground.
      def allow_without_authentication!
        @allow_without_authentication = true
      end

      def allow_without_authentication?
        @allow_without_authentication
      end

      # Whether a request may be served at all.
      def authorized_access_configured?
        !@authorize_block.nil? || @allow_without_authentication
      end

      def resolved_title
        @title || default_title
      end

      private

      def default_title
        app = defined?(Rails) && Rails.respond_to?(:application) && Rails.application
        name = app&.class&.module_parent_name
        name ? "#{name.underscore.humanize} admin" : 'Admin'
      end
    end
  end
end
