module CrudComponents
  module Admin
    # View helpers for the engine's own templates. Included explicitly by the
    # engine's controllers, so they never reach the host app's views.
    module ViewHelpers
      # The engine's index path for a registered model. Built from the engine's
      # own route set rather than a bare helper name, which a host helper of the
      # same name would shadow.
      def admin_index_path(entry)
        CrudComponents::Admin.path_for(entry.model, :index)
      end

      def admin_icon(name, css_class: nil)
        return nil unless name

        tag.i(nil, class: ["#{CrudComponents.config.css.icon_prefix}#{name}", css_class].compact.join(' '))
      end

      # Whether this entry is the one being looked at.
      def admin_current_entry?(entry)
        params[:crud_model].to_s == entry.name
      end

      def admin_title = CrudComponents::Admin.config.resolved_title

      # The admin layout's stylesheet, inlined (CSP-nonce aware).
      def admin_styles
        nonce = content_security_policy_nonce if respond_to?(:content_security_policy_nonce)
        tag.style(CrudComponents::Admin.bundled_css.html_safe, type: 'text/css', nonce: nonce)
      end

      # The bulk action deleting the ticked rows, or nil for a model that has
      # no destroy route.
      def admin_destroy_selected_action(entry)
        return nil unless entry.allows?(:destroy)

        CrudComponents::Action.new(
          :destroy_selected, on: :selection, method: :delete, confirm: true, icon: 'trash',
          title: t('crud_components.admin.destroy_selected', default: 'Delete selected')
        ) { public_send("destroy_selected_#{entry.route_key}_path") }
      end

      # The delete button: a link to the confirmation page rather than a DELETE
      # behind a browser dialog. Keeps the derived action's icon and label.
      def admin_delete_action(entry)
        return nil unless entry.allows?(:destroy)

        CrudComponents::Action.new(:destroy, on: :row, method: :get, confirm: false) do |record|
          public_send("delete_#{entry.singular_route_key}_path", record)
        end
      end

      # The row action linking a record to the host app's own page for it.
      # Resolves through crud_app_path, so it disappears when there is none.
      def admin_show_in_app_action
        CrudComponents::Action.new(
          :show_in_app, on: :row, icon: 'box-arrow-up-right',
          title: t('crud_components.admin.show_in_app', default: 'Show in app')
        ) { |record| crud_app_path(record) }
      end

      # Active Storage routes live in the application's route set, not in an
      # isolated engine's. Attachment cells reach them through these three.
      def url_for(options = nil)
        return main_app.url_for(options) if active_storage_object?(options)

        super
      end

      def polymorphic_url(record, options = {})
        return main_app.polymorphic_url(record, options) if active_storage_object?(record)

        super
      end

      def polymorphic_path(record, options = {})
        return main_app.polymorphic_path(record, options) if active_storage_object?(record)

        super
      end

      # A route helper the engine does not have falls through to the host
      # application's routes — the admin renders the host's partials and render
      # blocks, and those call the host's routes.
      def method_missing(name, *args, **options, &block)
        return super unless forwardable_route_helper?(name)

        main_app.public_send(name, *args, **options, &block)
      end

      def respond_to_missing?(name, include_private = false)
        forwardable_route_helper?(name) || super
      end

      private

      def forwardable_route_helper?(name)
        return false unless name.to_s.end_with?('_path', '_url')
        return false unless respond_to?(:main_app)

        main_app.respond_to?(name)
      end

      def active_storage_object?(object)
        defined?(ActiveStorage) && object.class.name.to_s.start_with?('ActiveStorage::')
      end
    end
  end
end
