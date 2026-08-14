CrudComponents::Admin::Engine.routes.draw do
  root 'dashboard#show'

  registry = CrudComponents::Admin.registry
  drawn = {}

  registry.entries.each do |entry|
    next if entry.actions.empty?

    if (clash = drawn[entry.route_key])
      raise CrudComponents::Admin::Error,
            "#{entry.name} and #{clash} both route to /#{entry.route_key} — " \
            'drop one with `admin false` or `config.except`'
    end

    drawn[entry.route_key] = entry.name
    resources entry.route_key, controller: 'resources', only: entry.actions,
                               defaults: { crud_model: entry.name } do
      if entry.allows?(:destroy)
        collection { delete :destroy_selected, controller: 'resources' }
        member { get :delete, controller: 'resources' }
      end

      # An index per to-many association pointing here, so the owner's
      # "+n more" links and its association cells resolve.
      entry.nested_associations(registry).each do |association|
        resources association.route_key, controller: 'resources', only: :index,
                                         defaults: { crud_model: association.name,
                                                     crud_association: association.association.to_s,
                                                     crud_owner: entry.name }
      end
    end
  end
end
