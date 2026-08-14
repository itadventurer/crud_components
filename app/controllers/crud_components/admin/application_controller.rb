module CrudComponents
  module Admin
    # Base for the engine's controllers. Inherits from the host's controller
    # (see `config.parent_controller`), so `current_user`, the session and any
    # `rescue_from` are the app's own.
    class ApplicationController < CrudComponents::Admin.config.parent_controller_class
      # Active Storage's route helpers live in the application's route set, not
      # in an isolated engine's — attachment cells call them by bare name.
      ACTIVE_STORAGE_HELPERS = %i[
        rails_blob_path rails_blob_url rails_representation_path rails_representation_url
        rails_storage_proxy_path rails_storage_proxy_url
        rails_storage_redirect_path rails_storage_redirect_url
      ].freeze

      layout -> { CrudComponents::Admin.config.layout }
      helper CrudComponents::Admin::ViewHelpers

      helper do
        ACTIVE_STORAGE_HELPERS.each do |helper_name|
          define_method(helper_name) do |*args, **options|
            main_app.public_send(helper_name, *args, **options)
          end
        end
      end

      before_action :run_admin_gate!

      rescue_from CrudComponents::Admin::ForbiddenError do |error|
        render plain: error.message, status: :forbidden
      end

      helper_method :admin_config, :admin_registry, :admin_entries, :admin_entry_groups

      private

      def admin_config = CrudComponents::Admin.config

      def admin_registry = CrudComponents::Admin.registry

      # The models the navigation offers: routed, allowed, and with a table
      # behind them (a half-migrated database leaves one out rather than
      # offering a link that only errors).
      def admin_entries
        @admin_entries ||= admin_registry.entries.select do |entry|
          CrudComponents::Admin.path_for(entry.model, :index) && readable?(entry) && table?(entry)
        end
      end

      def table?(entry)
        entry.model.table_exists?
      rescue ActiveRecord::ActiveRecordError
        true
      end

      def admin_entry_groups = admin_registry.groups(admin_entries)

      def readable?(entry)
        ability = admin_ability
        ability.nil? || ability.can?(:index, entry.model)
      end

      # The entry's relation, narrowed by the ability when one can scope.
      def admin_scope(entry)
        scope = entry.scope
        ability = cancan_ability
        return scope unless ability && scope.respond_to?(:accessible_by)

        scope.accessible_by(ability)
      end

      def run_admin_gate!
        gate = Gate.new(admin_config, admin_ability)

        case gate.verdict
        when :block then instance_exec(&admin_config.auth_block)
        when :unauthorized then raise UnauthorizedError, gate.unauthorized_message
        when :forbidden
          # Through the host's `authorize!` first, so its own `rescue_from` decides.
          authorize!(Gate::ACTION, admin_config.auth_subject) if respond_to?(:authorize!, true)
          raise ForbiddenError, gate.forbidden_message
        end
      end

      # Whatever answers `can?` here: a CanCanCan ability, else the controller
      # itself when the host defined `can?` on it, else nothing.
      def admin_ability
        return @admin_ability if defined?(@admin_ability)

        @admin_ability = if respond_to?(:current_ability, true) then current_ability
                         elsif respond_to?(:can?, true) then self
                         end
      end

      # Only a real CanCanCan ability can scope a relation.
      def cancan_ability
        current_ability if respond_to?(:current_ability, true)
      end
    end
  end
end
