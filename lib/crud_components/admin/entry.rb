module CrudComponents
  module Admin
    # One registered model: everything the route drawer, the sidebar and the
    # controller need, resolved once.
    class Entry
      # The seven RESTful actions, in the order routes are drawn.
      ALL_ACTIONS = %i[index show new create edit update destroy].freeze

      # Actions a member route needs a primary key for.
      MEMBER_ACTIONS = %i[show edit update destroy].freeze

      # `new` without `create` (or `edit` without `update`) is a form that can't
      # submit, so each implies the other.
      ACTION_PAIRS = { new: :create, create: :new, edit: :update, update: :edit }.freeze

      attr_reader :model, :options

      def initialize(model, options = {})
        @model = model
        @options = options || {}
      end

      def name = model.name

      def structure = Structure.for(model)

      def route_key = model.model_name.route_key

      def singular_route_key = model.model_name.singular_route_key

      # The column a URL segment is matched against, from `identify_by`.
      def param_key = structure.identify_by

      def label = options[:label]&.to_s || model.model_name.human(count: 2)

      def icon = structure.icon

      # nil for a top-level model; the namespace for `Catalog::Book`.
      def group
        return options[:group].to_s if options[:group]

        namespace = name.to_s.deconstantize
        namespace.presence&.demodulize&.underscore&.humanize
      end

      def actions
        @actions ||= resolve_actions
      end

      def allows?(action) = actions.include?(action.to_sym)

      def read_only? = (actions & %i[new create edit update destroy]).empty?

      # The base relation the admin renders, before filtering and sorting.
      def scope
        base = model.all
        callable = options[:scope]
        return base unless callable

        callable.arity.zero? ? base.instance_exec(&callable) : callable.call(base)
      end

      # The index fieldset: `:admin` when declared, else the usual default.
      def fieldset
        return options[:fieldset].to_sym if options[:fieldset]

        structure.declared_fieldset_names.include?(:admin) ? :admin : nil
      end

      def to_s = name

      private

      # Routes are drawn without a database in reach often enough (an asset
      # build, a container ahead of its migrations), and asking for the primary
      # key raises there; assume the ordinary case.
      def primary_key?
        !model.primary_key.nil?
      rescue StandardError
        true
      end

      def resolve_actions
        declared = options[:actions]
        list = declared ? Array(declared).map(&:to_sym) : ALL_ACTIONS.dup
        list |= list.filter_map { |action| ACTION_PAIRS[action] }
        list &= ALL_ACTIONS
        list -= MEMBER_ACTIONS unless primary_key?
        ALL_ACTIONS & list
      end
    end
  end
end
