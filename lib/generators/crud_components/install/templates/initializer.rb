# CrudComponents — everything has a working default; uncomment to deviate.
CrudComponents.configure do |config|
  # belongs_to filter selects switch to a text input over the target's
  # search_in beyond this many records:
  # config.select_limit = 250

  # CSS class map (Bootstrap 5 defaults). The full key list:
  # CrudComponents::Config::DEFAULT_CSS
  # config.css.table  = 'table table-sm table-hover'
  # config.css.button = 'btn btn-sm btn-outline-dark'
end
