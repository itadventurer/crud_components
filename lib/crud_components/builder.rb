module CrudComponents
  # Evaluates a `crud_structure do ... end` block. Collects declarations;
  # Structure resolves and validates them against what Rails knows.
  class Builder
    attr_reader :model, :declarations, :actions, :fieldsets,
                :label_decl, :identify_by_decl, :search_decl

    def initialize(model, &block)
      @model = model
      @declarations = {}
      @actions = {}
      @fieldsets = {}
      instance_exec(&block)
    end

    def label(method = nil, &block)
      raise DefinitionError, "#{model}: label declared twice" if defined?(@label_decl) && @label_decl
      raise DefinitionError, "#{model}: label takes a method name or a block, not both" if method && block
      raise DefinitionError, "#{model}: label needs a method name or a block" unless method || block

      @label_decl = block || method.to_sym
    end

    def identify_by(column)
      raise DefinitionError, "#{model}: identify_by declared twice" if @identify_by_decl

      @identify_by_decl = column.to_sym
    end

    def search_in(*spec, &block)
      raise DefinitionError, "#{model}: search_in declared twice" if @search_decl
      raise DefinitionError, "#{model}: search_in takes a spec or a block, not both" if spec.any? && block
      raise DefinitionError, "#{model}: search_in needs a spec or a block" if spec.empty? && !block

      @search_decl = block || spec
    end

    def attribute(name, **options, &block)
      name = name.to_sym
      if @declarations.key?(name)
        raise DefinitionError, "#{model}: attribute :#{name} declared twice — merge the declarations"
      end
      if RESERVED_PARAMS.include?(name.to_s)
        raise DefinitionError, "#{model}: :#{name} is a reserved param name " \
                               "(#{RESERVED_PARAMS.join(', ')}) and cannot be a field"
      end

      @declarations[name] = { options: options, facets: parse_facets(name, block) }
    end

    def attributes(*names, **options)
      raise DefinitionError, "#{model}: attributes needs at least one name" if names.empty?

      names.each { |name| attribute(name, **options) }
    end

    def action(name, **options, &path_block)
      name = name.to_sym
      raise DefinitionError, "#{model}: action :#{name} declared twice" if @actions.key?(name)

      @actions[name] = Action.new(name, **options, &path_block)
    end

    def fieldset(name, fields = :all, actions: nil, filters: nil)
      name = name.to_sym
      raise DefinitionError, "#{model}: fieldset :#{name} declared twice" if @fieldsets.key?(name)

      @fieldsets[name] = Fieldset.new(name, fields, actions: actions, filters: filters)
    end

    private

    # Bare block taking the record (arity 1, including `it`/`_1`) is the
    # render facet; a zero-arity block declares facets.
    def parse_facets(name, block)
      return {} unless block
      return { render: block } unless block.arity.zero?

      FacetCollector.new(model, name).collect(&block)
    end

    class FacetCollector
      NONE = Object.new

      def initialize(model, name)
        @model = model
        @name = name
        @facets = {}
      end

      def collect(&block)
        instance_exec(&block)
        @facets
      end

      def render(*args, &block)
        once!(:render)
        unless block && args.empty?
          raise DefinitionError, "#{where}: the render facet takes only a block — " \
                                 'named renderers are picked with the as: keyword on attribute'
        end

        @facets[:render] = block
      end

      # A like-spec passed positionally (same mini-language as `search_in`):
      #   filter :title                       own column
      #   filter :title, :subtitle            several columns, OR-combined
      #   filter authors: %i[name email]      join, explicit columns
      #   filter :publisher                   join, delegate to the target's search_in
      #   filter :title, { authors: :name }   mixed
      # plus `filter false` (off) and `filter { |scope, value| ... }` (block).
      def filter(*spec, **assoc, &block)
        once!(:filter)
        if assoc.key?(:like)
          raise DefinitionError, "#{where}: the `like:` keyword was removed — pass the spec directly, " \
                                 "e.g. `filter #{Array(assoc[:like]).map(&:inspect).join(', ')}`"
        end
        spec << assoc unless assoc.empty?

        case
        when spec == [false] && !block then @facets[:filter] = false
        when block && spec.empty? then @facets[:filter] = block
        when !spec.empty? && !block then @facets[:filter] = spec.size == 1 ? spec.first : spec
        else
          raise DefinitionError, "#{where}: filter takes `false`, a column/association spec " \
                                 '(e.g. `filter :title` or `filter authors: %i[name email]`), or a block'
        end
      end

      def sort(arg = NONE, &block)
        once!(:sort)
        case
        when arg == false && !block then @facets[:sort] = false
        when block && arg.equal?(NONE) then @facets[:sort] = block
        when arg.is_a?(Symbol) && !block then @facets[:sort] = arg
        else
          raise DefinitionError, "#{where}: sort takes `false`, an own-column symbol, or a block"
        end
      end

      def method_missing(name, *)
        raise DefinitionError, "#{where}: unknown facet '#{name}' — facets are render, filter and sort"
      end

      def respond_to_missing?(_name, _include_private = false) = true

      private

      def once!(facet)
        raise DefinitionError, "#{where}: #{facet} facet declared twice" if @facets.key?(facet)
      end

      def where = "#{@model} attribute :#{@name}"
    end
  end
end
