module CrudComponents
  # A button, per row or per collection. Derived defaults (:new, :show, :edit,
  # :destroy) are self-disabling: they render only when permitted and their
  # conventional route resolves (see RouteResolver).
  class Action
    DERIVED = {
      new: { on: :collection, icon: 'plus-lg' },
      show: { on: :row, icon: 'eye' },
      edit: { on: :row, icon: 'pencil' },
      destroy: { on: :row, icon: 'trash', method: :delete, confirm: true, danger: true }
    }.freeze

    KNOWN_OPTIONS = %i[on icon title class confirm method if].freeze

    attr_reader :name, :icon, :on, :http_method, :path_block

    def initialize(name, derived: false, **options, &path_block)
      unknown = options.keys - KNOWN_OPTIONS
      if unknown.any?
        raise DefinitionError, "action :#{name}: unknown option(s) #{unknown.map(&:inspect).join(', ')} — " \
                               "known: #{KNOWN_OPTIONS.map(&:inspect).join(', ')}"
      end

      defaults = DERIVED[name.to_sym] || {}
      @name = name.to_sym
      @derived = derived
      @on = options[:on] || defaults[:on] || :row
      @icon = options.key?(:icon) ? options[:icon] : defaults[:icon]
      @title_option = options[:title]
      @css_class = options[:class]
      @confirm = options.key?(:confirm) ? options[:confirm] : defaults[:confirm]
      @http_method = options[:method] || defaults[:method] || :get
      @condition = options[:if]
      @path_block = path_block
      @danger = defaults[:danger] || false
    end

    def derived? = @derived
    def danger? = @danger
    def collection? = @on == :collection
    def row? = !collection?

    def confirm_message
      return nil unless @confirm

      @confirm == true ? I18n.t('crud_components.confirm', default: 'Are you sure?') : @confirm
    end

    def title
      @title_option || I18n.t("crud_components.actions.#{name}", default: name.to_s.humanize)
    end

    def css_class(config = CrudComponents.config)
      @css_class || (danger? ? config.css.button_danger : config.css.button)
    end

    # `context` is the view (when CanCanCan's `can?` is around) or anything
    # can?-shaped. Without an explicit `if:` and without `can?`, the action
    # is shown — permissions are opt-in, not a dependency.
    def permitted?(context, record_or_model)
      if @condition
        model = record_or_model.is_a?(Class) ? record_or_model : record_or_model.class
        record = record_or_model.is_a?(Class) ? nil : record_or_model
        Permission.permitted?(@condition, model, context, record)
      elsif context.respond_to?(:can?)
        context.can?(name, record_or_model)
      else
        true
      end
    end
  end
end
