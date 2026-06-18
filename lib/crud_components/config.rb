require 'active_support/ordered_options'

module CrudComponents
  class Config
    # When changed, add it to initializer.rb
    DEFAULT_CSS = {
      table: 'table align-middle',
      thead: '',
      toolbar: 'd-flex justify-content-between align-items-center gap-2 mb-2',
      search_form: 'd-flex gap-1',
      filter_row: 'crud-filter-row',
      sort_link: 'text-reset text-decoration-none',
      record_link: 'fw-medium',
      filter_link: 'text-reset text-decoration-none',
      actions_cell: 'text-end',
      button_group: 'btn-group btn-group-sm',
      button: 'btn btn-sm btn-outline-secondary',
      button_primary: 'btn btn-sm btn-primary',
      button_danger: 'btn btn-sm btn-outline-danger',
      pagination: 'pagination pagination-sm',
      badge: 'badge text-bg-secondary',
      badge_muted: 'badge text-bg-light',
      input: 'form-control',
      input_sm: 'form-control form-control-sm',
      # named *_input to avoid OrderedOptions#select (Hash#select) collisions
      select_input: 'form-select',
      select_input_sm: 'form-select form-select-sm',
      form_label: 'form-label',
      form_summary: 'alert alert-danger',
      filter_grid: 'row row-cols-1 g-2',
      input_group: 'input-group flex-nowrap',
      boolean_true: 'text-success',
      boolean_false: 'text-danger',
      muted: 'text-muted',
      # icon font base + name prefix; built-in icon names are Bootstrap Icons.
      # Swap the whole library here, e.g. 'fa fa-' for Font Awesome.
      icon_prefix: 'bi bi-',
      dl: 'row',
      dt: 'col-sm-3',
      dd: 'col-sm-9'
    }.freeze

    # Icon name (no library prefix — paired with css.icon_prefix) for each
    # derived action. Override a glyph, or set one to nil for no icon:
    #   config.action_icons[:destroy] = 'trash-fill'
    DEFAULT_ACTION_ICONS = {
      new: 'plus-lg', show: 'eye', edit: 'pencil', destroy: 'trash'
    }.freeze

    # Map of file extension → icon name (no library prefix — paired with
    # css.icon_prefix) for the attachment icon fallback; an unmapped extension
    # uses file_fallback_icon. Full names (not a prefix) so non-conforming ones
    # fit too — e.g. yaml→filetype-yml, zip→file-earmark-zip. Bootstrap Icons'
    # whole `filetype-*` family is included; override/extend per your set.
    DEFAULT_FILE_ICONS = %w[
      aac ai bmp cs css csv doc docx exe gif heic html java jpg js json jsx key
      m4p md mdx mov mp3 mp4 otf pdf php png ppt pptx psd py raw rb sass scss sh
      sql svg tiff tsx ttf txt wav woff xls xlsx xml yml
    ].to_h { |ext| [ext, "filetype-#{ext}"] }.merge(
      'yaml' => 'filetype-yml',          # alias of yml
      'jpeg' => 'filetype-jpg',          # alias of jpg
      'zip'  => 'file-earmark-zip'       # no filetype- glyph exists
    ).freeze

    attr_accessor :select_limit, :group_collapse_threshold, :action_icons,
                  :file_icons, :file_fallback_icon, :fast_cells
    attr_reader :css

    def initialize
      @select_limit = 250
      # Grouped collections open every group when the total row count is below
      # this, and only the first group above it (the rest collapse).
      @group_collapse_threshold = 50
      # Render built-in cell types inline (in Ruby) instead of one partial per
      # cell — an order of magnitude faster on big tables. A host override of a
      # field partial is still honored; set false to force partials everywhere.
      @fast_cells = true
      @css = ActiveSupport::OrderedOptions.new.merge!(DEFAULT_CSS)
      @action_icons = DEFAULT_ACTION_ICONS.dup
      @file_icons = DEFAULT_FILE_ICONS.dup
      @file_fallback_icon = 'file-earmark-text'
    end
  end
end
