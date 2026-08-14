module CrudComponents
  module Admin
    # What else goes when a record is destroyed: the associations that declare a
    # `dependent:` behaviour, counted, plus the ones that would block it.
    class Dependents
      DESTROYING = %i[destroy destroy_async delete_all].freeze
      BLOCKING = %i[restrict_with_error restrict_with_exception].freeze

      # How many of an item's records the confirmation page names.
      PREVIEW = 10

      Item = Struct.new(:name, :model, :count, :behavior, :cascades, :records, keyword_init: true) do
        def destroys? = DESTROYING.include?(behavior)

        # What is left over once the named ones are shown.
        def unnamed = count - Array(records).size

        def blocks? = BLOCKING.include?(behavior) && count.positive?

        def nullifies? = behavior == :nullify

        def human_name
          return name.to_s.humanize unless model

          human = model.model_name.human(count: count)
          count == 1 ? human : human.pluralize(I18n.locale)
        end
      end

      def self.for(record) = new(record).items

      def initialize(record)
        @record = record
      end

      def items
        @items ||= (association_items + attachment_items).reject { |item| item.count.zero? }
      end

      # Anything that blocks the delete outright.
      def blockers = items.select(&:blocks?)

      private

      attr_reader :record

      def association_items
        support = Structure.for(record.class).attachment_support_names

        record.class.reflect_on_all_associations.filter_map do |reflection|
          behavior = reflection.options[:dependent]&.to_sym
          next unless behavior
          next if support.include?(reflection.name)

          Item.new(name: reflection.name, model: target_of(reflection), count: count_for(reflection),
                   behavior: behavior, cascades: cascades?(reflection), records: preview_of(reflection))
        end
      end

      # Attached files go with the record; they are not an association the app
      # declared, so they are counted separately.
      def attachment_items
        return [] unless record.class.respond_to?(:reflect_on_all_attachments)

        record.class.reflect_on_all_attachments.map do |reflection|
          attached = record.public_send(reflection.name)
          count = attached.respond_to?(:count) ? attached.count : (attached.attached? ? 1 : 0)
          Item.new(name: reflection.name, model: nil, count: count, behavior: :destroy, cascades: false,
                   records: [])
        end
      end

      def target_of(reflection)
        reflection.klass
      rescue NameError
        nil
      end

      def count_for(reflection)
        value = record.public_send(reflection.name)
        return value.count if value.respond_to?(:count)

        value.nil? ? 0 : 1
      rescue ActiveRecord::ActiveRecordError, NameError
        0
      end

      # The first records the delete would reach, for naming them.
      def preview_of(reflection)
        value = record.public_send(reflection.name)
        return Array(value) unless value.respond_to?(:limit)

        value.limit(PREVIEW).to_a
      rescue ActiveRecord::ActiveRecordError, NameError
        []
      end

      # Whether the target itself destroys further records — the count shown is
      # then the first level only.
      def cascades?(reflection)
        target = target_of(reflection)
        return false unless target && DESTROYING.include?(reflection.options[:dependent]&.to_sym)

        target.reflect_on_all_associations.any? do |nested|
          DESTROYING.include?(nested.options[:dependent]&.to_sym)
        end
      end
    end
  end
end
