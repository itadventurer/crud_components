module CrudComponents
  # The minimal context `if:` conditions run in when there is no view around
  # (i.e. inside Query). Exposes `can?` backed by the passed ability; without
  # an ability nothing is permitted — safe by default.
  class PermissionContext
    def initialize(ability)
      @ability = ability
    end

    def can?(action, subject)
      return false unless @ability

      @ability.can?(action, subject)
    end
  end

  # Shared evaluation of `if:` options on attributes and actions.
  # The callable receives the record (`it`) — or nil for column-level
  # decisions — and runs in a context where `can?` works.
  module Permission
    module_function

    def permitted?(condition, model, context, record = nil)
      return true if condition.nil?

      case condition
      when Symbol
        # Sugar for can?(symbol, record) — the record being decided about — so a
        # symbol matches the derived action check (can?(:edit, @book)). For a
        # column-level decision there is no record, so fall back to the model
        # class (can?(symbol, Book)).
        context.can?(condition, record || model)
      when Proc
        if condition.lambda? && condition.arity.zero?
          context.instance_exec(&condition)
        else
          context.instance_exec(record, &condition)
        end
      else
        condition.respond_to?(:call) ? condition.call(record) : !!condition
      end
    end
  end
end
