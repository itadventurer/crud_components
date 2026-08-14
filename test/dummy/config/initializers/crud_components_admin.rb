# The playground is a public demo, so the admin has no gate at all. A real app
# leaves the default `auth_with :cancan` alone — see docs/admin.md.
CrudComponents::Admin.configure do |config|
  config.auth_with :none
  config.title = 'Bookstore admin'
  config.parent_controller = 'ApplicationController'
end
