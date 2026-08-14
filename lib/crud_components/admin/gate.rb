module CrudComponents
  module Admin
    # Who may in, as one verdict the controller only has to carry out.
    class Gate
      VERDICTS = %i[open block unauthorized allowed forbidden].freeze

      def initialize(config, ability, entries)
        @config = config
        @ability = ability
        @entries = entries
      end

      def verdict
        return :open if @config.open_gate?
        return :block if @config.auth_block
        return :unauthorized if @ability.nil?
        return :allowed if granted_on_any_model?

        :forbidden
      end

      def unauthorized_message
        "The admin authorizes on `can?(#{permission.inspect}, …)`, and nothing here answers `can?`. " \
          'Add CanCanCan, or configure a gate of your own: ' \
          'CrudComponents::Admin.configure { |c| c.auth_with { … } } — ' \
          "or say `c.auth_with :none` on purpose (see docs/admin.md).\n" \
          "In an ability: `can #{permission.inspect}, :all`."
      end

      def forbidden_message = "not allowed to #{permission} here"

      private

      def permission = @config.auth_action

      # The gate opens for a limited admin too, so `can :crud_admin, [Book]`
      # gets in and sees Books only.
      def granted_on_any_model?
        @entries.any? { |entry| @ability.can?(permission, entry.model) }
      end
    end
  end
end
