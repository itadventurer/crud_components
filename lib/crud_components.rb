require 'bigdecimal'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/date_and_time/calculations'
require 'active_support/core_ext/integer/time'

module CrudComponents
  # The query params the gem owns (filters are top-level params named after the
  # field, so a field can't share these names). Declaring such an attribute
  # raises in the Builder rather than silently colliding with sort/pagination.
  RESERVED_PARAMS = %w[q sort dir page per cols].freeze

  # Sentinel filter value meaning "the column is NULL" (boolean/enum filters on
  # nullable columns offer it as a "not set" choice). Improbable as a real
  # value, so it never collides with a genuine enum key or boolean string.
  NULL_FILTER_VALUE = '__null__'.freeze

  # The two non-blank values of an association/attachment **presence** filter —
  # its 3-state control (any / present / absent) submits these, and the query
  # turns them into an EXISTS / NOT EXISTS (`where.associated` / `where.missing`)
  # rather than a value match. See {Fields::PresenceFilter}.
  PRESENT_FILTER_VALUE = 'present'.freeze
  ABSENT_FILTER_VALUE = 'absent'.freeze
end

require_relative 'crud_components/version'
require_relative 'crud_components/errors'
require_relative 'crud_components/config'
require_relative 'crud_components/permission_context'
require_relative 'crud_components/like_spec'
require_relative 'crud_components/where_like'
require_relative 'crud_components/typed_filter'
require_relative 'crud_components/fields/base'
require_relative 'crud_components/fields/presence_filter'
require_relative 'crud_components/fields/string_field'
require_relative 'crud_components/fields/text_field'
require_relative 'crud_components/fields/numeric_field'
require_relative 'crud_components/fields/date_field'
require_relative 'crud_components/fields/boolean_field'
require_relative 'crud_components/fields/enum_field'
require_relative 'crud_components/fields/json_field'
require_relative 'crud_components/fields/attachment_field'
require_relative 'crud_components/fields/belongs_to_field'
require_relative 'crud_components/fields/has_many_field'
require_relative 'crud_components/fields/computed_field'
require_relative 'crud_components/fields/path_field'
require_relative 'crud_components/fields/dynamic_field'
require_relative 'crud_components/dynamic_column'
require_relative 'crud_components/action'
require_relative 'crud_components/fieldset'
require_relative 'crud_components/builder'
require_relative 'crud_components/structure'
require_relative 'crud_components/model'
require_relative 'crud_components/query'

module CrudComponents
  class << self
    def config
      @config ||= Config.new
    end

    def configure
      yield config
    end

    def structure_for(model)
      Structure.for(model)
    end

    # Safe case-insensitive contains-match on any relation, using the same
    # escaped-ILIKE machinery as `filter like:` / `search_in` — so you never
    # hand-write `where("col LIKE ?", "%#{value}%")` (which forgets to escape the
    # user's `%`/`_`). The scope handed to a filter/search block already carries
    # `#where_like`; this module function is for the relations you build yourself,
    # e.g. a subquery on another model:
    #
    #   filter: ->(scope, value) {
    #     ids = CrudComponents.where_like(PropertyValue.where(definition: prop), :value, value)
    #     scope.where(id: ids.select(:subject_id))
    #   }
    #
    # `spec` is a {LikeSpec} spec (`:value`, `%i[a b]`, `{ assoc: :col }`).
    def where_like(relation, spec, value)
      LikeSpec.apply(relation, spec, value)
    end

    # The column-picker selection from a request's params: the ordered list of
    # column names the user ticked, or nil when the picker wasn't submitted.
    # Honors `param_prefix:` (match it to the picker's). Persist it however you
    # like, then feed it back via `picked_columns:`.
    #
    #   cols = CrudComponents.selected_columns(params)
    #   current_user.update!(book_columns: cols) if cols
    #
    # A block runs only when a selection was submitted, and receives the list:
    #
    #   CrudComponents.selected_columns(params) { |cols| current_user.update!(book_columns: cols) }
    #
    # Accepts both the no-JS `cols[]=a&cols[]=b` array and the comma-joined
    # `cols=a,b` the crud-columns controller submits.
    def selected_columns(params, param_prefix: nil)
      key = param_prefix ? "#{param_prefix}_cols" : 'cols'
      raw = params[key] || params[key.to_sym]
      list = raw.is_a?(Array) ? raw : raw.is_a?(String) ? raw.split(',') : nil
      names = list&.map { |n| n.to_s.strip }&.reject(&:blank?)
      names = nil if names.nil? || names.empty?
      yield names if block_given? && names
      names
    end

    # Whether non-image attachment previews (e.g. a PDF's first page) can
    # actually be generated here. Beyond a previewer binary (poppler/ffmpeg,
    # which `previewable?` already checks), processing needs `image_processing`
    # plus the configured variant backend's gem (ruby-vips or mini_magick).
    # When any is missing, the renderer shows an icon + filename rather than a
    # preview that would 500 at processing time.
    # @api private
    def previews_available?
      return @previews_available if defined?(@previews_available)

      @previews_available = begin
        require 'image_processing'
        processor = defined?(ActiveStorage) ? ActiveStorage.variant_processor : :vips
        require(processor.to_s == 'mini_magick' ? 'mini_magick' : 'vips')
        true
      rescue LoadError
        false
      end
    end

    # The strong-params permit list for a model's derived form — the same
    # field metadata the form renders from, so the two can't drift. Use in a
    # controller:
    #   params.require(:book)
    #         .permit(*CrudComponents.permitted_attributes(Book, action: :update,
    #                                                       ability: current_ability))
    def permitted_attributes(model, action: :update, ability: nil)
      Structure.for(model).permitted_params(action, PermissionContext.new(ability))
    end

    # Resolve a bulk-action selection from request params into a relation. The
    # row checkboxes submit `selected[]=<identify_by>` (a slug array; a comma
    # string is also accepted).
    #
    # Pass the same authorized scope you'd render — selection narrows *within*
    # it, so a tampered slug can never reach a row outside it:
    #   CrudComponents.selected(@books, params).destroy_all   # @books already scoped
    # A model class also works when you don't scope (acts on the whole table):
    #   CrudComponents.selected(Book, params)
    def selected(scope, params, param: :selected)
      model = scope.respond_to?(:klass) ? scope.klass : scope
      values = Array(params[param]).flat_map { |v| v.to_s.split(',') }.map(&:strip).reject(&:blank?)
      scope.where(Structure.for(model).identify_by => values)
    end

    # The gem's stylesheet (the column-picker float styles), read once from the
    # packaged file. Backs the `crud_components_styles` helper, which inlines it;
    # the same file is also linkable via `stylesheet_link_tag "crud_components"`
    # on hosts whose asset pipeline serves engine assets.
    def bundled_css
      @bundled_css ||= File.read(File.expand_path('../app/assets/stylesheets/crud_components.css', __dir__))
    end
  end
end

require_relative 'crud_components/engine' if defined?(Rails::Engine)
