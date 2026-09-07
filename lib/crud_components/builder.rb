# frozen_string_literal: true

module CrudComponents
  # The DSL evaluated inside `crud_structure do … end`. Its instance methods —
  # {#attribute}, {#attributes}, {#action}, {#fieldset}, {#label},
  # {#identify_by}, {#search_in} — are the public declaration API; the block
  # runs against a Builder instance. It only collects declarations; {Structure}
  # resolves and validates them against what Rails already knows.
  #
  # @example
  #   class Book < ApplicationRecord
  #     include CrudComponents::Model
  #     crud_structure do
  #       label :title
  #       identify_by :slug
  #       attribute :title  { filter :title; sort :title }
  #       fieldset :index, %i[title author], actions: %i[edit destroy]
  #     end
  #   end
  class Builder
    attr_reader :model, :declarations, :actions, :fieldsets,
                :label_decl, :identify_by_decl, :search_decl,
                :label_preload_decl, :preload_decl, :icon_decl, :admin_decl,
                :app_path_decl

    # @param model [Class] the ActiveRecord model being described.
    # @yield the `crud_structure` block, evaluated against this Builder.
    # @api private
    def initialize(model, &)
      @model = model
      @declarations = {}
      @actions = {}
      @fieldsets = {}
      instance_exec(&)
    end

    # How a record is titled (links, headings). Give a method name or a block.
    # @param method [Symbol, nil] a method on the record returning its label.
    # @param preload [Array<Symbol>, Symbol, nil] associations the label reaches
    #   into (`label :display_title, preload: %i[publisher authors]`). They're
    #   eager-loaded automatically whenever this model is shown as another
    #   model's association column — declare once, no N+1 anywhere.
    # @yield [record] computes the label; receives the record.
    # @return [void]
    def label(method = nil, preload: nil, &block)
      raise DefinitionError, "#{model}: label declared twice" if defined?(@label_decl) && @label_decl
      raise DefinitionError, "#{model}: label takes a method name or a block, not both" if method && block
      raise DefinitionError, "#{model}: label needs a method name or a block" unless method || block

      @label_decl = block || method.to_sym
      @label_preload_decl = preload_list(preload)
    end

    # Associations to eager-load whenever this model is rendered (as a row or as
    # another model's association cell) — for label/render dependencies the gem
    # can't infer. Additive with `label …, preload:`; declare more than once to
    # accumulate. e.g. `preload :publisher, :authors`.
    # @param names [Array<Symbol>] association names (nested hashes allowed).
    # @return [void]
    def preload(*names)
      @preload_decl = (@preload_decl || []) + names
    end

    # The column used in URLs (`to_param`) and to resolve a bulk selection.
    # @param column [Symbol] e.g. `:slug`. Defaults to `:id` when undeclared.
    # @return [void]
    def identify_by(column)
      raise DefinitionError, "#{model}: identify_by declared twice" if @identify_by_decl

      @identify_by_decl = column.to_sym
    end

    # The icon (no library prefix — paired with `css.icon_prefix`) that badges
    # this model wherever it appears: column-picker groups, association links,
    # path-column cells. Overrides the name-based guess in `config.model_icons`.
    # @param name [String, Symbol] a Bootstrap-icon name, e.g. `'building'`.
    # @return [void]
    def icon(name)
      raise DefinitionError, "#{model}: icon declared twice" if @icon_decl

      @icon_decl = name.to_s
    end

    # The columns/associations full-text search (`?q=`) spans, in the same
    # mini-language as the positional `filter` spec.
    # @param spec [Array<Symbol, Hash>] e.g. `:title, authors: %i[name email]`.
    # @yield [scope, term] a custom search; receives the scope and the term.
    # @return [void]
    def search_in(*spec, &block)
      raise DefinitionError, "#{model}: search_in declared twice" if @search_decl
      raise DefinitionError, "#{model}: search_in takes a spec or a block, not both" if spec.any? && block
      raise DefinitionError, "#{model}: search_in needs a spec or a block" if spec.empty? && !block

      @search_decl = block || spec
    end

    # Declare (or refine) one attribute. The optional block sets facets: a
    # one-arity block is the render facet; a zero-arity block declares
    # `filter`/`sort`/`render` (see {FacetCollector}).
    # @param name [Symbol] the attribute/column/association name.
    # @param options [Hash] e.g. `as:` (renderer), `form_as:`, `if:`,
    #   `editable:`, `label:`, `null:`.
    # @yield optional facet block.
    # @return [void]
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

    # Declare several attributes that share the same options.
    # @param names [Array<Symbol>] one or more attribute names.
    # @param options [Hash] applied to each (see {#attribute}).
    # @return [void]
    def attributes(*names, **options)
      raise DefinitionError, "#{model}: attributes needs at least one name" if names.empty?

      names.each { |name| attribute(name, **options) }
    end

    # Declare a custom action button. The block returns its path, evaluated in
    # the view context (and given the record for a row action).
    # @param name [Symbol] the action name (also the i18n/route key).
    # @param options [Hash] `on:` (`:row`/`:collection`/`:selection`), `icon:`,
    #   `title:`, `class:`, `confirm:`, `method:`, `if:`.
    # @yield the path block.
    # @return [void]
    def action(name, **, &)
      name = name.to_sym
      raise DefinitionError, "#{model}: action :#{name} declared twice" if @actions.key?(name)

      @actions[name] = Action.new(name, **, &)
    end

    # A named selection of fields + actions for a surface (index/show/form/…).
    # @param name [Symbol] the fieldset name.
    # @param fields [Array<Symbol>, :all] which fields, in order (`:all` = every
    #   declared/derived field).
    # @param actions [Array<Symbol>, nil] curate the actions (per kind); nil keeps
    #   the derived defaults.
    # @param filters [Array<Symbol>, nil] filterable fields beyond the visible ones.
    # @return [void]
    def fieldset(name, fields = :all, actions: nil, filters: nil)
      name = name.to_sym
      raise DefinitionError, "#{model}: fieldset :#{name} declared twice" if @fieldsets.key?(name)

      @fieldsets[name] = Fieldset.new(name, fields, actions: actions, filters: filters)
    end

    # The host application's own page for a record, when it is not the
    # conventional route (`main_app.book_path(book)`). Runs in the view
    # context; return nil to suppress the link for a record.
    #   app_path { |book| main_app.publisher_book_path(book.publisher, book) }
    # @yield [record] the record to link to.
    # @return [void]
    def app_path(&block)
      raise DefinitionError, "#{model}: app_path requires a block" unless block
      raise DefinitionError, "#{model}: app_path declared twice" if defined?(@app_path_decl) && @app_path_decl

      @app_path_decl = block
    end

    # How this model appears in the mounted admin UI (inert without it).
    # @param enabled [Boolean] `false` keeps the model out of the admin entirely.
    # @param options [Hash] `actions:` (a subset of
    #   `%i[index show new create edit update destroy]`), `group:`, `label:`,
    #   `fieldset:`, `scope:` (a callable narrowing the base relation).
    # @return [void]
    # `admin false` is the documented way to keep a model out, so the boolean
    # stays positional — a keyword here would break every caller.
    def admin(enabled = true, **options) # rubocop:disable Style/OptionalBooleanParameter
      raise DefinitionError, "#{model}: admin declared twice" if defined?(@admin_decl) && !@admin_decl.nil?

      unless [true, false].include?(enabled)
        raise DefinitionError, "#{model}: admin takes true or false, got #{enabled.inspect}"
      end

      if enabled == false && options.any?
        raise DefinitionError, "#{model}: `admin false` takes no options — #{options.keys.map(&:inspect).join(', ')} " \
                               'would never apply'
      end

      validate_admin_options!(options)
      @admin_decl = enabled ? options : false
    end

    private

    ADMIN_OPTIONS = %i[actions group label fieldset scope].freeze
    private_constant :ADMIN_OPTIONS

    def validate_admin_options!(options)
      unknown = options.keys - ADMIN_OPTIONS
      unless unknown.empty?
        raise DefinitionError, "#{model}: admin got unknown option(s) #{unknown.map(&:inspect).join(', ')} — " \
                               "known: #{ADMIN_OPTIONS.map(&:inspect).join(', ')}"
      end

      actions = options[:actions]
      return if actions.nil?

      bad = Array(actions).map(&:to_sym) - Admin::Entry::ALL_ACTIONS
      return if bad.empty?

      raise DefinitionError, "#{model}: admin actions #{bad.map(&:inspect).join(', ')} are not RESTful actions — " \
                             "known: #{Admin::Entry::ALL_ACTIONS.map(&:inspect).join(', ')}"
    end

    # Normalize a preload value to an array of includes-specs, leaving a nested
    # hash (`{ publisher: :books }`) intact (Array() would split it).
    def preload_list(value)
      case value
      when nil then []
      when Array then value
      else [value]
      end
    end

    # Bare block taking the record (arity 1, including `it`/`_1`) is the
    # render facet; a zero-arity block declares facets.
    def parse_facets(name, block)
      return {} unless block
      return { render: block } unless block.arity.zero?

      FacetCollector.new(model, name).collect(&block)
    end

    # Gathers the facets of one attribute (render / filter / sort) while its
    # block runs, so the builder sees them as a single declaration.
    class FacetCollector
      NONE = Object.new

      def initialize(model, name)
        @model = model
        @name = name
        @facets = {}
      end

      def collect(&)
        instance_exec(&)
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
        spec << assoc unless assoc.empty?

        if spec == [false] && !block
          @facets[:filter] = false
        elsif block && spec.empty?
          @facets[:filter] = block
        elsif !spec.empty? && !block
          @facets[:filter] = spec.size == 1 ? spec.first : spec
        else
          raise DefinitionError, "#{where}: filter takes `false`, a column/association spec " \
                                 '(e.g. `filter :title` or `filter authors: %i[name email]`), or a block'
        end
      end

      def sort(arg = NONE, &block)
        once!(:sort)
        if arg == false && !block
          @facets[:sort] = false
        elsif block && arg.equal?(NONE)
          @facets[:sort] = block
        elsif arg.is_a?(Symbol) && !block
          @facets[:sort] = arg
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
