# CrudComponents — everything has a working default; uncomment to deviate.
CrudComponents.configure do |config|
  # belongs_to filter selects switch to a text input over the target's
  # search_in beyond this many records:
  # config.select_limit = 250

  # CSS class map (Bootstrap 5 defaults). The full key list:
  # CrudComponents::Config::DEFAULT_CSS  
  # config.css.table = 'table align-middle'
  # config.css.thead = ''
  # config.css.filter_row = 'crud-filter-row'
  # config.css.sort_link = 'text-reset text-decoration-none'
  # config.css.actions_cell = 'text-end'
  # config.css.button_group = 'btn-group btn-group-sm'
  # config.css.button = 'btn btn-sm btn-outline-secondary'
  # config.css.button_primary = 'btn btn-sm btn-primary'
  # config.css.button_danger = 'btn btn-sm btn-outline-danger'
  # config.css.pagination = 'pagination pagination-sm'  # footer pager (paginated relations)
  # config.css.badge = 'badge text-bg-secondary'
  # config.css.badge_muted = 'badge text-bg-light'
  # config.css.input = 'form-control'
  # config.css.input_sm = 'form-control form-control-sm'
  # # named *_input to avoid OrderedOptions#select (Hash#select) collisions
  # config.css.select_input = 'form-select'
  # config.css.select_input_sm = 'form-select form-select-sm'
  # config.css.form_label = 'form-label'
  # config.css.filter_grid = 'row row-cols-1 g-2'
  # config.css.input_group = 'input-group flex-nowrap'
  # config.css.boolean_true = 'text-success'
  # config.css.boolean_false = 'text-danger'
  # config.css.muted = 'text-muted'
  # config.css.dl = 'row'
  # config.css.dt = 'col-sm-3'
  # config.css.dd = 'col-sm-9'
end
