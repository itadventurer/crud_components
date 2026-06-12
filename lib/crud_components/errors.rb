module CrudComponents
  class Error < StandardError; end

  # DSL misuse, detected when the structure is built (boot / first use).
  class DefinitionError < Error; end

  # An explicitly requested fieldset that the model does not declare.
  class UnknownFieldsetError < Error; end
end
