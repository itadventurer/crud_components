module CrudComponents
  # A named selection of fields and actions — never a definition. `filters:`
  # extends the filterable set beyond the visible fields ("filter only what
  # you can see" is the default rule).
  class Fieldset
    attr_reader :name, :field_names, :action_spec, :filter_names

    def initialize(name, fields = :all, actions: nil, filters: nil)
      @name = name.to_sym
      @field_names = fields == :all ? :all : Array(fields).map(&:to_sym)
      @action_spec = actions
      @filter_names = Array(filters || []).map(&:to_sym)
    end

    def all_fields? = @field_names == :all

    # actions: %i[edit destroy] — a curated list of action names
    def action_names
      @action_spec.is_a?(Array) ? @action_spec.map(&:to_sym) : nil
    end

    # actions: 'books/actions' — a custom partial receiving `record`
    def custom_actions_partial
      @action_spec.is_a?(String) ? @action_spec : nil
    end
  end
end
