# frozen_string_literal: true

module CrudComponents
  module Fields
    # The target records an association's filter select and form select offer.
    # Never more than the ability may see: the target relation goes through
    # `accessible_by` when the ability can scope, and a per-field `choices:`
    # callable narrows it further (or decides alone where there is no such
    # ability):
    #   attribute :publisher, choices: ->(scope) { scope.where(active: true) }
    #   attribute :publisher, choices: ->(scope, ability) { scope.select { ability.can?(:show, it) } }
    # The callable receives the (already scoped) target relation, plus the
    # ability when it takes two arguments, and returns a relation or an array of
    # records.
    module AssociationChoices
      # The target records to offer, sorted by label as [label, record] pairs.
      def choice_records(ability)
        structure = target_structure
        records = Permission.accessible(target.all, ability)
        records = call_choices(records, ability) if options[:choices]
        records.to_a.map { |record| [structure.label_for(record).to_s, record] }.sort_by(&:first)
      end

      def declared_choices? = !options[:choices].nil?

      # Form select options, [label, id]. What the record already points at is
      # always offered, so saving an untouched form never silently reassigns it
      # to the first choice the viewer happens to see.
      def form_choices(ability = nil, record = nil)
        pairs = choice_records(ability)
        current = record ? Array(record.public_send(name)).compact : []
        missing = current.reject { |target_record| pairs.any? { |_, offered| offered == target_record } }
        (pairs + missing.map { |target_record| [target_structure.label_for(target_record).to_s, target_record] })
          .map { |label, target_record| [label, target_record.id] }
      end

      private

      def call_choices(records, ability)
        choices = options[:choices]
        arity = choices.respond_to?(:arity) ? choices.arity : 1
        arity == 1 ? choices.call(records) : choices.call(records, ability)
      end
    end
  end
end
