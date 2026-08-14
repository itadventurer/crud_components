require 'delegate'

module CrudComponents
  module Admin
    # The ability the admin asks in :cancan mode: the admin's own action stands
    # in for every finer one, so `can :crud_admin, :all` grants the whole admin
    # while narrower rules still grant on their own.
    class Ability < SimpleDelegator
      def initialize(ability, permission)
        super(ability)
        @permission = permission
      end

      def can?(action, subject)
        __getobj__.can?(@permission, subject) || __getobj__.can?(action, subject)
      end

      def cannot?(action, subject) = !can?(action, subject)
    end
  end
end
