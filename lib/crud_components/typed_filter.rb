module CrudComponents
  # The mechanism behind a typed dynamic-column filter (built internally by
  # {Fields::Base} — you don't construct one). It pairs a value type with an apply
  # block: the type drives casting and the rendered control, the block reaches SQL.
  #
  # A {DynamicColumn} gets one when its `filter:` block declares keyword params; the
  # type comes from the column's `as:` (overridable with `filter_as:`). The block
  # declares which of `eq:` / `geq:` / `leq:` / `contains:` it handles and is called
  # with only those — each value already cast to the type (numeric → BigDecimal,
  # date → Date, boolean → true/false), or nil when the param is blank or doesn't
  # parse. Which control renders follows from the type and the declared keywords: a
  # numeric/date block that asks for a bound (`geq:`/`leq:`) renders a range; one
  # that asks only for `eq:` renders a single field.
  #
  # @api private
  class TypedFilter
    TYPES = %i[text numeric date boolean select].freeze

    # Every keyword a block may declare. The bare `?field=` value binds to
    # `contains:` when the block asks for it, otherwise to `eq:`; the `_geq`/`_leq`
    # params bind to `geq:`/`leq:`.
    KEYWORDS = %i[eq contains geq leq choices].freeze

    attr_reader :type, :choices

    def initialize(type, apply, choices: nil)
      unless TYPES.include?(type)
        raise ArgumentError, "unknown filter type #{type.inspect} — one of #{TYPES.map(&:inspect).join(', ')}"
      end
      raise ArgumentError, 'a typed filter needs an apply block (a callable)' unless apply.respond_to?(:call)

      @type = type
      @apply = apply
      @choices = choices
      @keywords = declared_keywords(apply)
    end

    # The filter partial to render (`crud_components/filters/_<control>`).
    def control
      case type
      when :numeric then range? ? :number_range : :number
      when :date    then range? ? :date_range : :date
      else type
      end
    end

    # Apply with the raw param values (Strings or nil): `value` is the bare
    # `?field=`, `geq`/`leq` the bounds. Each is cast to the type and routed to the
    # keyword the block declared; a value that doesn't cast becomes nil, so junk
    # never reaches SQL.
    def apply(scope, value: nil, geq: nil, leq: nil)
      single = (@keywords.include?(:contains) && !@keywords.include?(:eq)) ? :contains : :eq
      values = { single => cast(value), geq: cast(geq), leq: cast(leq), choices: @choices }
      @apply.call(scope, **values.slice(*@keywords))
    end

    # The `[label, value]` pairs a `:select` offers, or nil for any other type. A
    # callable `choices` is resolved here (passed the query when it takes an arg).
    def filter_choices(query = nil)
      return nil unless type == :select

      raw = @choices.respond_to?(:call) ? (@choices.arity.zero? ? @choices.call : @choices.call(query)) : @choices
      Array(raw).map { |opt| opt.is_a?(Array) ? opt : [opt.to_s, opt] }
    end

    private

    TRUE_VALUES = %w[true t 1 yes on].freeze
    FALSE_VALUES = %w[false f 0 no off].freeze

    def range? = (@keywords & %i[geq leq]).any?

    # The keywords the block declared. A block with `**` (keyrest) takes everything.
    def declared_keywords(apply)
      params = apply.respond_to?(:parameters) ? apply.parameters : []
      return KEYWORDS if params.any? { |kind, _| kind == :keyrest }

      params.filter_map { |kind, name| name if %i[key keyreq].include?(kind) }
    end

    def cast(value)
      return nil if value.nil? || (value.respond_to?(:empty?) && value.empty?)

      case type
      when :numeric then cast_decimal(value)
      when :date    then cast_date(value)
      when :boolean then cast_boolean(value)
      else value
      end
    end

    def cast_decimal(value)
      decimal = BigDecimal(value.to_s)
      decimal.finite? ? decimal : nil
    rescue ArgumentError, TypeError
      nil
    end

    def cast_date(value)
      Date.parse(value.to_s)
    rescue ArgumentError, TypeError, RangeError
      nil
    end

    def cast_boolean(value)
      down = value.to_s.downcase
      return true if TRUE_VALUES.include?(down)
      return false if FALSE_VALUES.include?(down)

      nil
    end
  end
end
