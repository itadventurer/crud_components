CrudComponents::Admin::Engine.routes.draw do
  root 'dashboard#show'

  drawn = {}
  CrudComponents::Admin.registry.entries.each do |entry|
    next if entry.actions.empty?

    if (clash = drawn[entry.route_key])
      raise CrudComponents::Admin::Error,
            "#{entry.name} and #{clash} both route to /#{entry.route_key} — " \
            'drop one with `admin false` or `config.except`'
    end

    drawn[entry.route_key] = entry.name
    resources entry.route_key, controller: 'resources', only: entry.actions,
                               defaults: { crud_model: entry.name }
  end
end
