# frozen_string_literal: true

module CrudComponents
  # `include CrudComponents::Model` adds the crud_structure DSL. It is only
  # needed to declare things — rendering works for any ActiveRecord model.
  module Model
    def self.included(base)
      base.extend(ClassMethods)
      return unless base.respond_to?(:before_validation)

      base.before_validation :crud_apply_secret_input
      base.before_save :crud_apply_secret_input
      base.after_save { @crud_secret_removals = nil }
    end

    # ── secret attributes (`attribute :api_token, secret: true`) ────────────
    # An empty value keeps what is stored; `remove_api_token = '1'` clears it.
    # A form (or a JSON response) never gets the value back, so an empty field
    # means "unchanged", not "erase". A new value typed in wins over the box.
    REMOVE_PREFIX = 'remove_'
    TRUTHY = ['1', 'true', 'on', 'yes', true].freeze
    private_constant :REMOVE_PREFIX, :TRUTHY

    def serializable_hash(options = nil)
      secrets = self.class.crud_secret_attributes.map(&:to_s)
      return super if secrets.empty?

      options = options ? options.dup : {}
      options[:except] = Array(options[:except]).map(&:to_s) | secrets
      super
    end

    def respond_to_missing?(name, include_private = false)
      !crud_secret_removal_name(name).nil? || super
    end

    def method_missing(name, *args)
      attribute = crud_secret_removal_name(name)
      return super unless attribute

      removals = (@crud_secret_removals ||= Set.new)
      return removals.include?(attribute) unless name.end_with?('=')

      TRUTHY.include?(args.first) ? removals << attribute : removals.delete(attribute)
      args.first
    end

    # What including CrudComponents::Model adds to the model class itself:
    # the crud_structure declaration and access to the built structure.
    module ClassMethods
      def crud_structure(&block)
        raise ArgumentError, 'crud_structure requires a block' unless block

        if instance_variable_defined?(:@_crud_structure_block) && @_crud_structure_block
          raise DefinitionError, "crud_structure already declared on #{self} — merge the two blocks " \
                                 '(the second one would otherwise silently win)'
        end

        @_crud_structure_block = block
        @_crud_structure = nil
        @_crud_secret_attributes = nil
      end

      # The attributes declared `secret: true` (see {SecretField}).
      def crud_secret_attributes
        return @_crud_secret_attributes if @_crud_secret_attributes

        @_crud_secret_attributes = Structure.secret_attribute_names(self)
      end

      # The strong-params permit list is {CrudComponents.permitted_attributes}
      # (a model class works whether or not it includes this concern), so there
      # is one way to ask for it — no model-side alias to drift from it.

      # For tests and code reloading.
      def reset_crud_structure!
        @_crud_structure_block = nil
        @_crud_structure = nil
        @_crud_secret_attributes = nil
      end
    end

    private

    # :api_token for `remove_api_token` / `remove_api_token=` on a secret, else nil.
    def crud_secret_removal_name(name)
      text = name.to_s
      return nil unless text.start_with?(REMOVE_PREFIX)

      attribute = text.delete_prefix(REMOVE_PREFIX).delete_suffix('=').to_sym
      self.class.crud_secret_attributes.include?(attribute) ? attribute : nil
    end

    def crud_apply_secret_input
      self.class.crud_secret_attributes.each do |attribute|
        typed = attribute_changed?(attribute) && self[attribute].present?
        if @crud_secret_removals&.include?(attribute) && !typed
          self[attribute] = nil
        elsif attribute_changed?(attribute) && self[attribute].blank?
          restore_attributes([attribute])
        end
      end
    end
  end
end
