module CrudComponents
  module Presenters
    # Resolves a list of actions for a subject (record or model class) into
    # renderable items. Derived actions are self-disabling: no permission or
    # no resolvable route → no button, never a broken link.
    class Actions < Base
      Item = Struct.new(:action, :path, keyword_init: true)

      def initialize(view:, subject:, structure: nil, actions: nil, owner: nil, suppress_show: false)
        super(view: view)
        @subject = subject
        @model = subject.is_a?(Class) ? subject : subject.class
        @structure = structure || Structure.for(@model)
        @list = actions
        @owner = owner
        @suppress_show = suppress_show
      end

      def kind = @subject.is_a?(Class) ? :collection : :row

      def items
        @items ||= list.filter_map do |action|
          next if action.name == :show && action.derived? && @suppress_show
          next unless action.permitted?(permission_context, @subject)

          path = RouteResolver.action_path(view, action,
                                           record: kind == :row ? @subject : nil,
                                           model: @model, owner: @owner)
          next unless path

          Item.new(action: action, path: path)
        end
      end

      def any? = items.any?

      private

      def list
        @list || @structure.fieldset_actions(@structure.default_fieldset, on: kind)
      end
    end
  end
end
