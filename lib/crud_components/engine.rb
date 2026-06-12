require_relative 'route_resolver'
require_relative 'markup'
require_relative 'presenters/base'
require_relative 'presenters/actions'
require_relative 'presenters/collection'
require_relative 'presenters/record'
require_relative 'presenters/filter'
require_relative 'helpers'

module CrudComponents
  # Dependency-free engine: adds the gem's view path (partials under
  # app/views/crud_components/), the helpers, and the generators.
  class Engine < ::Rails::Engine
    initializer 'crud_components.helpers' do
      ActiveSupport.on_load(:action_view) do
        include CrudComponents::Helpers
      end
    end
  end
end
