# frozen_string_literal: true

module CrudComponents
  module Admin
    # Who may in at all, as one verdict the controller only has to carry out.
    # It decides nothing beyond the door: what a visitor may see and do inside
    # is the app's ordinary ability, asked per model and per action.
    class Gate
      ACTION = :access

      VERDICTS = %i[open block unauthorized allowed forbidden].freeze

      def initialize(config, ability)
        @config = config
        @ability = ability
      end

      def verdict
        return :open if @config.open_gate?
        return :block if @config.auth_block
        return :unauthorized if @ability.nil?
        return :allowed if @ability.can?(ACTION, subject)

        :forbidden
      end

      def unauthorized_message
        "The admin asks `can?(#{ACTION.inspect}, #{subject.inspect})`, and nothing here answers `can?`. " \
          'Add CanCanCan, or configure a gate of your own: ' \
          'CrudComponents::Admin.configure { |c| c.auth_with { … } } — ' \
          "or say `c.auth_with :none` on purpose (see docs/admin.md).\n" \
          "In an ability: `can #{ACTION.inspect}, #{subject.inspect}`."
      end

      def forbidden_message = "not allowed to #{ACTION} the admin"

      private

      def subject = @config.auth_subject
    end
  end
end
