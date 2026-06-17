module CrudComponents
  # A named selection of fields and actions. `filters:`
  # extends the filterable set beyond the visible fields ("filter only what
  # you can see" is the default rule).
  class Fieldset
    attr_reader :name, :field_names, :action_spec, :filter_names

    # @param name [Symbol] the fieldset name.
    # @param fields [Array<Symbol>, :all] the fields, in order (`:all` = every
    #   declared/derived field).
    # @param actions [Array<Symbol>, String, nil] a curated list of action names,
    #   or a custom partial path; nil keeps the derived actions.
    # @param filters [Array<Symbol>, nil] filterable fields beyond the visible ones.
    def initialize(name, fields = :all, actions: nil, filters: nil)
      @name = name.to_sym
      @field_names = fields == :all ? :all : Array(fields).map(&:to_sym)
      @action_spec = actions
      @filter_names = Array(filters || []).map(&:to_sym)
    end

    # @return [Boolean] whether this fieldset shows every field.
    def all_fields? = @field_names == :all

    # The curated action names (`actions: %i[edit destroy]`), or nil when the
    # derived defaults apply.
    # @return [Array<Symbol>, nil]
    def action_names
      @action_spec.is_a?(Array) ? @action_spec.map(&:to_sym) : nil
    end

    # A custom actions partial (`actions: 'books/actions'`, receiving `record`),
    # or nil.
    # @return [String, nil]
    def custom_actions_partial
      @action_spec.is_a?(String) ? @action_spec : nil
    end
  end
end
