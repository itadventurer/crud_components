require 'active_support/ordered_options'

module CrudComponents
  class Config
    DEFAULT_CSS = {
      table: 'table align-middle',
      thead: '',
      filter_row: 'crud-filter-row',
      sort_link: 'text-reset text-decoration-none',
      actions_cell: 'text-end',
      button_group: 'btn-group btn-group-sm',
      button: 'btn btn-sm btn-outline-secondary',
      button_primary: 'btn btn-sm btn-primary',
      button_danger: 'btn btn-sm btn-outline-danger',
      badge: 'badge text-bg-secondary',
      badge_muted: 'badge text-bg-light',
      input: 'form-control',
      input_sm: 'form-control form-control-sm',
      select: 'form-select',
      select_sm: 'form-select form-select-sm',
      form_label: 'form-label',
      filter_grid: 'row row-cols-1 g-2',
      input_group: 'input-group flex-nowrap',
      boolean_true: 'text-success',
      boolean_false: 'text-danger',
      muted: 'text-muted',
      dl: 'row',
      dt: 'col-sm-3',
      dd: 'col-sm-9'
    }.freeze

    attr_accessor :select_limit
    attr_reader :css

    def initialize
      @select_limit = 250
      @css = ActiveSupport::OrderedOptions.new.merge!(DEFAULT_CSS)
    end
  end
end
