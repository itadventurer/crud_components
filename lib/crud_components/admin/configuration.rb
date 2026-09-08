# frozen_string_literal: true

module CrudComponents
  module Admin
    # What the mounted admin needs to know that the models don't say themselves.
    #
    #   CrudComponents::Admin.configure do |config|
    #     config.auth_with { head :forbidden unless current_user&.admin? }
    #     config.title = 'Bookstore admin'
    #   end
    class Configuration
      # Model name prefixes that are framework bookkeeping, not application data.
      DEFAULT_EXCLUDED_NAMESPACES = %w[
        ActiveRecord ActiveStorage ActionText ActionMailbox
        SolidQueue SolidCache SolidCable
        Delayed GoodJob Que Noticed PgSearch FriendlyId
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

      # How the admin decides who gets in: :cancan, :none, or :block when
      # `auth_with` was given one. See {#auth_with}.
      attr_reader :auth_mode

      # The `before_action` body that decides who gets in, for `auth_with { … }`.
      attr_reader :auth_block

      # What the :cancan gate asks about: `can?(:access, auth_subject)`.
      attr_accessor :auth_subject

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
        @auth_mode = :cancan
        @auth_subject = :crud_admin
        @auth_block = nil
      end

      # The resolved parent controller class, falling back to ActionController::Base
      # when the named one does not exist.
      def parent_controller_class
        @parent_controller.to_s.safe_constantize || ActionController::Base
      end

      # Who gets in. Three forms:
      #
      #   config.auth_with :cancan                 # the default: `can :access, :crud_admin`
      #   config.auth_with :cancan, subject: :backend
      #   config.auth_with :none                   # no gate at all — a demo, a playground
      #   config.auth_with { redirect_to main_app.root_path unless current_user&.admin? }
      #
      # A block runs as a `before_action` in the engine's controller, in that
      # controller's own context — `current_user`, `redirect_to`, `head` and
      # your `rescue_from`s all work as usual.
      def auth_with(mode = nil, subject: nil, &block)
        raise ArgumentError, 'auth_with takes a mode or a block, not both' if mode && block

        @auth_subject = subject if subject
        @auth_mode = block ? :block : normalized_mode(mode)
        @auth_block = block
      end

      def cancan_gate? = @auth_mode == :cancan

      def open_gate? = @auth_mode == :none

      def resolved_title
        @title || default_title
      end

      private

      MODES = %i[cancan cancancan ability none].freeze

      def normalized_mode(mode)
        raise ArgumentError, "auth_with: unknown mode #{mode.inspect}, one of #{MODES.inspect}" unless
          MODES.include?(mode)

        mode == :none ? :none : :cancan
      end

      def default_title
        app = defined?(Rails) && Rails.respond_to?(:application) && Rails.application
        name = app&.class&.module_parent_name
        name ? "#{name.underscore.humanize} admin" : 'Admin'
      end
    end
  end
end
