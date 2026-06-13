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

      # Strong-params permit list for this model's derived form. Convenience
      # wrapper around CrudComponents.permitted_attributes for included models:
      #   params.require(:book).permit(*Book.crud_attribute_names(:update, ability: current_ability))
      def crud_attribute_names(action = :update, ability: nil)
        CrudComponents.permitted_attributes(self, action: action, ability: ability)
      end

      # For tests and code reloading.
      def reset_crud_structure!
        @_crud_structure_block = nil
        @_crud_structure = nil
      end
    end
  end
end
