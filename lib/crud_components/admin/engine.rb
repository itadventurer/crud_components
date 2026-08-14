module CrudComponents
  module Admin
    # The mountable admin. Does nothing until an app mounts it:
    #
    #   mount CrudComponents::Admin::Engine => '/admin'
    #
    # Its routes are drawn from {Registry}, one `resources` block per model, all
    # pointing at ResourcesController.
    class Engine < ::Rails::Engine
      isolate_namespace CrudComponents::Admin

      # The gem root already holds app/ and config/locales; only the route file
      # is admin-specific, so point at it rather than at config/routes.rb (which
      # the non-isolated main engine would draw into the host application).
      paths['config/routes.rb'] = 'lib/crud_components/admin/routes.rb'

      config.after_initialize do |app|
        app.config.to_prepare { CrudComponents::Admin.registry.reload! }
      end
    end
  end
end
