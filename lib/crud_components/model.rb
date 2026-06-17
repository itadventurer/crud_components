module CrudComponents
  # `include CrudComponents::Model` adds the crud_structure DSL. It is only
  # needed to declare things — rendering works for any ActiveRecord model.
  module Model
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def crud_structure(&block)
        raise ArgumentError, 'crud_structure requires a block' unless block

        if instance_variable_defined?(:@_crud_structure_block) && @_crud_structure_block
          raise DefinitionError, "crud_structure already declared on #{self} — merge the two blocks " \
                                 '(the second one would otherwise silently win)'
        end

        @_crud_structure_block = block
        @_crud_structure = nil
      end

      # The strong-params permit list is {CrudComponents.permitted_attributes}
      # (a model class works whether or not it includes this concern), so there
      # is one way to ask for it — no model-side alias to drift from it.

      # For tests and code reloading.
      def reset_crud_structure!
        @_crud_structure_block = nil
        @_crud_structure = nil
      end
    end
  end
end
