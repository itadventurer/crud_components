# frozen_string_literal: true

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

      # Whether these could be deleted on their own. A cascade takes them either
      # way; the confirmation page says so. No ability means no opinion.
      def admin_may_destroy?(model)
        return true unless model && respond_to?(:can?)

        can?(:destroy, model)
      end

      # The ticked rows as one dependent item, so the confirmation page names
      # them the same way it names everything else that goes.
      def admin_selection_item(model, records)
        CrudComponents::Admin::Dependents::Item.new(
          name: nil, model: model, count: records.size, behavior: :destroy, cascades: false,
          records: records.first(CrudComponents::Admin::Dependents::PREVIEW)
        )
      end

      # What the ticked rows are identified by, for the form that deletes them.
      def admin_selected_values(records)
        records.map { |record| record.public_send(CrudComponents::Structure.for(record.class).identify_by).to_s }
      end

      # One record a delete would take, named: an attachment names its file and
      # opens it, anything else links to its own admin page.
      def admin_dependent_link(record, owner: nil)
        return admin_attachment_link(record) if admin_attachment?(record)

        path = crud_record_path(record, owner: owner)
        path ? link_to(crud_label(record), path, data: { turbo_action: 'advance' }) : crud_label(record)
      end

      # The index holding the rest of a dependent item: nested under the owner,
      # else the target's index filtered by it, else nil.
      def admin_dependents_path(owner, item)
        return nil unless item.model

        CrudComponents::RouteResolver.collection_index_path(self, item.model, owner, item.name)
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

      # The bulk action, or nil for a model with no destroy route. Like the row's
      # delete it leads to the confirmation page, not straight to a DELETE.
      def admin_destroy_selected_action(entry)
        return nil unless entry.allows?(:destroy)

        CrudComponents::Action.new(
          :destroy_selected, on: :selection, method: :get, confirm: false, icon: 'trash',
                             if: :destroy, title: t('crud_components.admin.destroy_selected', default: 'Delete selected')
        ) { public_send("delete_#{entry.route_key}_path") }
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
      # isolated engine's; attachment cells reach them through these two.
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
      def method_missing(name, ...)
        return super unless forwardable_route_helper?(name)

        main_app.public_send(name, ...)
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

      def admin_attachment?(record)
        defined?(ActiveStorage) && record.is_a?(ActiveStorage::Attachment)
      end

      # The filename, linked to the file itself; a blob that is gone is named
      # but not linked.
      def admin_attachment_link(attachment)
        blob = attachment.blob
        return attachment.name.to_s.humanize unless blob

        link_to(blob.filename.to_s, rails_blob_path(attachment, disposition: :inline),
                target: '_blank', rel: 'noopener')
      end

      def active_storage_object?(object)
        defined?(ActiveStorage) && object.class.name.to_s.start_with?('ActiveStorage::')
      end
    end
  end
end
