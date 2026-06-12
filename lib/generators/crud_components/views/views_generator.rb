module CrudComponents
  module Generators
    class ViewsGenerator < Rails::Generators::Base
      source_root File.expand_path('../../../../app/views/crud_components', __dir__)

      desc 'Copies all CrudComponents partials into your app for editing — ' \
           'a file at the same path wins over the gem version.'

      def copy_views
        directory '.', 'app/views/crud_components'
      end
    end
  end
end
