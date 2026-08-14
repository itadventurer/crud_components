# The playground is a public demo, so the admin has no gate at all. A real app
# configures `authorize_with` instead — see docs/admin.md.
CrudComponents::Admin.configure do |config|
  config.allow_without_authentication!
  config.title = 'Bookstore admin'
  config.parent_controller = 'ApplicationController'
end
