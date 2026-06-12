module CrudComponents
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Creates the CrudComponents initializer and copies the optional ' \
           'Stimulus controller (empty-param stripping + select auto-submit).'

      def create_initializer
        copy_file 'initializer.rb', 'config/initializers/crud_components.rb'
      end

      def copy_stimulus_controller
        copy_file 'crud_filter_controller.js', 'app/javascript/controllers/crud_filter_controller.js'
        say <<~NOTE

          The Stimulus controller is optional — everything works without it.
          If you use it, register it (stimulus-rails with importmap does this
          automatically via controllers/index.js; otherwise):

            import CrudFilterController from "./crud_filter_controller"
            application.register("crud-filter", CrudFilterController)

        NOTE
      end
    end
  end
end
