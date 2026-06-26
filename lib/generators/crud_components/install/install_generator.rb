module CrudComponents
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      desc 'Creates the CrudComponents initializer and copies the optional ' \
           'Stimulus controllers (filter niceties + habtm token/chip picker).'

      def create_initializer
        copy_file 'initializer.rb', 'config/initializers/crud_components.rb'
      end

      def copy_stimulus_controllers
        copy_file 'crud_filter_controller.js', 'app/javascript/controllers/crud_filter_controller.js'
        copy_file 'crud_multiselect_controller.js', 'app/javascript/controllers/crud_multiselect_controller.js'
        copy_file 'crud_select_controller.js', 'app/javascript/controllers/crud_select_controller.js'
        copy_file 'crud_columns_controller.js', 'app/javascript/controllers/crud_columns_controller.js'
        say <<~NOTE

          The Stimulus controllers are optional — everything works without them.
          - crud-filter: strip empty params on submit + auto-submit inline selects.
          - crud-multiselect: turn a habtm `<select multiple>` into a chips + add picker.
          - crud-select: "select all" / per-group checkboxes + a live count for bulk actions.
          - crud-columns: drag-to-reorder the column picker (ticking columns works without it).
          Register them (stimulus-rails with importmap does this automatically via
          controllers/index.js; otherwise):

            application.register("crud-filter", CrudFilterController)
            application.register("crud-multiselect", CrudMultiselectController)
            application.register("crud-select", CrudSelectController)
            application.register("crud-columns", CrudColumnsController)

        NOTE
      end
    end
  end
end
