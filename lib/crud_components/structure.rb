module CrudComponents
  # The resolved, validated description of how a model appears in the UI.
  # Built lazily per model class and memoized; works for models without any
  # declaration (rule zero: everything is derived from what Rails knows).
  class Structure
    RENDERER_GEMS = {
      markdown: %w[commonmarker redcarpet kramdown],
      asciidoc: %w[asciidoctor]
    }.freeze

    class << self
      def for(model)
        unless model.respond_to?(:columns_hash)
          raise ArgumentError, "#{model.inspect} is not an ActiveRecord model class"
        end

        cached = model.instance_variable_get(:@_crud_structure) if model.instance_variable_defined?(:@_crud_structure)
        return cached if cached

        structure = new(model, find_builder(model))
        model.instance_variable_set(:@_crud_structure, structure)
        structure
      end

      private

      # Class-level ivars are not inherited; walk up for STI subclasses.
      def find_builder(model)
        klass = model
        while klass.respond_to?(:instance_variable_defined?)
          if klass.instance_variable_defined?(:@_crud_structure_block)
            block = klass.instance_variable_get(:@_crud_structure_block)
            return Builder.new(model, &block) if block
          end
          klass = klass.superclass
          break if klass.nil? || klass == ActiveRecord::Base
        end
        nil
      end
    end

    # identity_preloads: associations to eager-load whenever this model is shown
    # as another model's association cell (its label/render dependencies), from
    # `label …, preload:` and the standalone `preload` declaration.
    attr_reader :model, :identify_by, :identity_preloads

    def initialize(model, builder = nil)
      @model = model
      @declarations = builder&.declarations || {}
      @label_decl = builder&.label_decl
      @identify_by = builder&.identify_by_decl || :id
      @search_decl = builder&.search_decl
      @identity_preloads = ((builder&.label_preload_decl || []) + (builder&.preload_decl || [])).uniq
      @declared_actions = builder&.actions || {}
      @declared_fieldsets = builder&.fieldsets || {}
      @fields = {}
      validate!
    end

    # ── fields ───────────────────────────────────────────────────────────────
    def field(name)
      @fields[name.to_sym] ||= resolve_field(name.to_sym)
    end

    # The :all set: every column (foreign keys swapped for their belongs_to),
    # then Active Storage attachments, then non-belongs_to associations
    # (has_many / habtm / has_one), then any declared computed fields — all
    # derived, in a stable order.
    def default_field_names
      @default_field_names ||= begin
        base = column_field_names + attachment_field_names + association_field_names
        base + (@declarations.keys - base)
      end
    end

    # Active Storage attachments (has_one_attached / has_many_attached),
    # surfaced as image fields — derived, no declaration needed.
    def attachment_field_names
      @attachment_field_names ||=
        model.respond_to?(:reflect_on_all_attachments) ? model.reflect_on_all_attachments.map(&:name) : []
    end

    # has_many / habtm / has_one — belongs_to already arrive via the FK swap.
    # Active Storage's generated join associations (images_attachments/_blobs)
    # and ActionText's rich-text associations are not user-facing columns.
    def association_field_names
      @association_field_names ||=
        model.reflect_on_all_associations.reject(&:belongs_to?).map(&:name)
              .reject { |n| n.to_s.start_with?('rich_text_', 'with_attached_') }
              .reject { |n| attachment_support_names.include?(n) }
    end

    # The join associations behind each attachment — excluded from the field
    # universe, since the attachment itself is the field.
    def attachment_support_names
      @attachment_support_names ||=
        attachment_field_names.flat_map do |att|
          %W[#{att}_attachment #{att}_attachments #{att}_blob #{att}_blobs].map(&:to_sym)
        end
    end

    # ── fieldsets ────────────────────────────────────────────────────────────
    # :default always exists; :index and :show fall back to :default when not
    # declared; any other name must be declared (typo protection).
    def fieldset(name = :default)
      name = (name || :default).to_sym
      return @declared_fieldsets[name] if @declared_fieldsets.key?(name)
      return default_fieldset if %i[default index show].include?(name)

      known = (@declared_fieldsets.keys + [:default]).uniq
      raise UnknownFieldsetError, "#{model} has no fieldset :#{name} — " \
                                  "available: #{known.map(&:inspect).join(', ')}"
    end

    def default_fieldset
      @default_fieldset ||= Fieldset.new(:default, :all)
    end

    def fieldset_fields(fieldset)
      names = fieldset.all_fields? ? default_field_names : fieldset.field_names
      names.map { |name| field(name) }
    end

    def fieldset_filter_fields(fieldset)
      (fieldset_fields(fieldset) + fieldset.filter_names.map { |name| field(name) })
        .uniq.select(&:filterable?)
    end

    def fieldset_sortable_fields(fieldset)
      fieldset_fields(fieldset).select(&:sortable?)
    end

    # ── forms ──────────────────────────────────────────────────────────────
    # Form field selection falls back most-specific-first:
    #   the action's own fieldset → :form → :default.
    def form_fieldset(action = nil)
      names = [action, :form, :default].compact
      names.each do |name|
        return @declared_fieldsets[name] if @declared_fieldsets.key?(name)
      end
      default_fieldset
    end

    # Editable, permitted fields of the form fieldset, as a strong-params
    # permit list (symbols and nested hashes) — the controller's single
    # source of truth, so form and params can never drift.
    def permitted_params(action, context)
      fields = fieldset_fields(form_fieldset(action))
      fields.select { |f| f.permitted?(context) && f.editable? && f.editable_permitted?(context) && f.form_control }
            .map(&:permit_param)
    end

    # ── identity ─────────────────────────────────────────────────────────────
    def label_source
      return @label_decl if @label_decl

      @label_source ||= %i[name title].find { |attr| model.columns_hash.key?(attr.to_s) } ||
                        model.columns.find { |col| col.type == :string }&.name&.to_sym
    end

    def label_for(record, context = nil)
      case (source = label_source)
      when Proc then context ? context.instance_exec(record, &source) : source.call(record)
      when Symbol then record.public_send(source)
      else "#{model.model_name.human} ##{record.id}"
      end
    end

    # The field whose cell carries the record link (nil for block labels).
    def label_field_name
      label_source.is_a?(Symbol) ? label_source : nil
    end

    # ── search ───────────────────────────────────────────────────────────────
    # nil when search_in is a custom block (delegation is then impossible).
    def search_in_spec
      return nil if @search_decl.is_a?(Proc)

      @search_in_spec ||= (@search_decl.presence || default_search_spec)
    end

    def default_search_spec
      model.columns.select { |col| %i[string text].include?(col.type) }
           .map { |col| col.name.to_sym }
    end

    def searchable?
      @search_decl.is_a?(Proc) || search_in_spec.any?
    end

    def apply_search(scope, query_string, permission: nil)
      if @search_decl.is_a?(Proc)
        @search_decl.call(scope.extending(WhereLike), query_string)
      else
        spec = permission ? permitted_search_spec(permission) : search_in_spec
        spec.any? ? LikeSpec.apply(scope, spec, query_string) : scope
      end
    end

    # A declared, permission-gated column (`attribute :x, if: :manage`) is
    # hidden everywhere including ?q= — so drop it from the search spec for a
    # user who may not see it. Undeclared columns in the default spec are
    # model-global search by design and stay.
    def permitted_search_spec(permission)
      search_in_spec.reject do |entry|
        entry.is_a?(Symbol) && model.columns_hash.key?(entry.to_s) &&
          @declarations.key?(entry) && !field(entry).permitted?(permission)
      end
    end

    # ── actions ──────────────────────────────────────────────────────────────
    def actions
      @actions ||= begin
        derived = %i[new show edit destroy].to_h { |name| [name, Action.new(name, derived: true)] }
        merged = derived.merge(@declared_actions)
        custom = @declared_actions.keys - derived.keys
        order = [:new, :show, :edit, *custom, :destroy]
        order.to_h { |name| [name, merged.fetch(name)] }
      end
    end

    def action(name)
      actions[name.to_sym] || raise(DefinitionError, "#{model} has no action :#{name} — " \
                                                     "available: #{actions.keys.map(&:inspect).join(', ')}")
    end

    # A fieldset's actions: list is authoritative per kind: listing only row
    # actions curates the row buttons without losing the derived :new button
    # (and vice versa). An empty list hides everything.
    def fieldset_actions(fieldset, on:)
      of_kind = ->(a) { a.public_send("#{on}?") }
      names = fieldset.action_names
      return actions.values.select(&of_kind) if names.nil?
      return [] if names.empty?

      listed = names.map { |name| action(name) }.select(&of_kind)
      listed.any? ? listed : actions.values.select(&of_kind)
    end

    # ── validation (DefinitionError with a way out, at first build) ──────────
    private

    def validate!
      @declarations.each_key { |name| field(name) }
      validate_renderer_gems!
      validate_fieldsets!
    end

    def validate_renderer_gems!
      @declarations.each do |name, decl|
        gems = RENDERER_GEMS[decl[:options][:as]]
        next unless gems
        next if gems.any? { |gem_name| try_require(gem_name) }

        raise DefinitionError, "#{model}.#{name}: as: :#{decl[:options][:as]} needs one of these gems " \
                               "in your bundle: #{gems.join(', ')}"
      end
    end

    def try_require(gem_name)
      require gem_name
      true
    rescue LoadError
      false
    end

    def validate_fieldsets!
      @declared_fieldsets.each_value do |fs|
        fs.field_names.each { |name| field(name) } unless fs.all_fields?
        fs.filter_names.each do |name|
          next if field(name).filterable?

          raise DefinitionError, "#{model}: fieldset :#{fs.name} lists :#{name} under filters:, " \
                                 'but that field is not filterable — give it a filter facet first'
        end
        fs.action_names&.each { |name| action(name) }
      end
    end

    def resolve_field(name)
      decl = @declarations[name] || {}
      field_class_for(name, decl[:facets] || {})
        .new(name, model, decl[:options] || {}, decl[:facets] || {})
    end

    def field_class_for(name, facets)
      if model.defined_enums.key?(name.to_s)
        Fields::EnumField
      elsif (reflection = model.reflect_on_association(name))
        reflection.collection? ? Fields::HasManyField : Fields::BelongsToField
      elsif model.respond_to?(:reflect_on_attachment) && model.reflect_on_attachment(name)
        Fields::AttachmentField
      elsif (column = model.columns_hash[name.to_s])
        column_field_class(column)
      elsif facets[:render] || model.method_defined?(name)
        Fields::ComputedField
      else
        raise DefinitionError, "#{model} has no column, enum, association or public method '#{name}'. " \
                               "Computed fields need a render facet: attribute(:#{name}) { |record| ... }"
      end
    end

    def column_field_class(column)
      case column.type
      when :text then Fields::TextField
      when :integer, :float, :decimal then Fields::NumericField
      when :date, :datetime, :timestamp, :timestamptz then Fields::DateField
      when :boolean then Fields::BooleanField
      when :json, :jsonb then Fields::JsonField
      else Fields::StringField
      end
    end

    def column_field_names
      @column_field_names ||= begin
        by_foreign_key = {}
        polymorphic_type_columns = []
        model.reflect_on_all_associations(:belongs_to).each do |ref|
          by_foreign_key[ref.foreign_key.to_s] = ref.name
          polymorphic_type_columns << ref.foreign_type.to_s if ref.polymorphic?
        end

        model.columns.filter_map do |col|
          next nil if polymorphic_type_columns.include?(col.name)

          by_foreign_key[col.name] || col.name.to_sym
        end.uniq
      end
    end
  end
end
