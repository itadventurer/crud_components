require 'bigdecimal'
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/date/calculations'
require 'active_support/core_ext/date_and_time/calculations'
require 'active_support/core_ext/integer/time'

module CrudComponents
  RESERVED_PARAMS = %w[q sort dir page per].freeze
end

require_relative 'crud_components/version'
require_relative 'crud_components/errors'
require_relative 'crud_components/config'
require_relative 'crud_components/permission_context'
require_relative 'crud_components/like_spec'
require_relative 'crud_components/where_like'
require_relative 'crud_components/fields/base'
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
  end
end

require_relative 'crud_components/engine' if defined?(Rails::Engine)
