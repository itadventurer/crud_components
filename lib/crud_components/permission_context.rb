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

  # Shared evaluation of `if:`/`editable:` options on attributes and actions. A
  # callable may depend on the **ability** (`can?` is available in its context),
  # the **record** (a one-arity lambda / `it`-proc receives it), or both:
  #   if: ->(book) { can?(:edit, book) && book.published? }
  #
  # `recordless:` is what a *record-dependent* condition evaluates to when there
  # is no record to decide about — a column-level / strong-params check, where
  # the lambda can't run (it would hit `nil`). It is `true` for visibility
  # (`if:` — show the column; the record/form surfaces still apply the
  # per-record decision) and `false` for editability (`editable:` — a
  # class-level permit list must not grant per-record write access, so stay
  # safe). Ability-only conditions (Symbol, zero-arity lambda) don't need a
  # record and are evaluated regardless.
  module Permission
    module_function

    def permitted?(condition, model, context, record = nil, recordless: true)
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
          context.instance_exec(&condition)          # ability-only — no record needed
        elsif record.nil?
          recordless                                 # record-dependent, but nothing to decide on
        else
          context.instance_exec(record, &condition)  # receives the record; can? still in scope
        end
      else
        if !condition.respond_to?(:call)
          !!condition
        elsif record.nil?
          recordless
        else
          condition.call(record)
        end
      end
    end
  end
end
