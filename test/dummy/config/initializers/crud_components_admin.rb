# frozen_string_literal: true

# The playground is a public demo, so the admin has no gate at all. A real app
# leaves the default `auth_with :cancan` alone — see docs/admin.md.
CrudComponents::Admin.configure do |config|
  config.auth_with :none
  config.title = 'Bookstore admin'
  config.parent_controller = 'ApplicationController'

  # Pages that are not models: a mounted dashboard, for admins only, and the
  # storefront itself.
  config.link 'Background jobs', path: -> { main_app.jobs_dashboard_path },
                                 group: 'Operations', icon: 'cpu',
                                 if: -> { can?(:manage, :jobs) }
  config.link :storefront, path: -> { main_app.root_path }, icon: 'shop'
end
