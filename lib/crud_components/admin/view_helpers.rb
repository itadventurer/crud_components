module CrudComponents
  module Admin
    # View helpers for the engine's own templates. Included explicitly by the
    # engine's controllers, so they never reach the host app's views.
    module ViewHelpers
      # The engine's index path for a registered model.
      def admin_index_path(entry)
        public_send("#{entry.route_key}_path")
      end

      def admin_icon(name, **options)
        return nil unless name

        tag.i(nil, class: "#{CrudComponents.config.css.icon_prefix}#{name}", **options)
      end

      def admin_title = CrudComponents::Admin.config.resolved_title

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

      private

      def active_storage_object?(object)
        defined?(ActiveStorage) && object.class.name.to_s.start_with?('ActiveStorage::')
      end
    end
  end
end
