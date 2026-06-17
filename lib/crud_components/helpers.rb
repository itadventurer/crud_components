module CrudComponents
  # The everyday view API, included into ActionView by the engine. Every helper
  # builds a presenter and renders a partial you can override via the host app's
  # view path (`app/views/crud_components/…`).
  module Helpers
    # A set of records as a table (or any layout partial you point `layout:` at).
    #
    # @param records [ActiveRecord::Relation] the rows to render. Pass a scope,
    #   not a model class, so your authorization and any pre-scoping apply before
    #   the gem renders (e.g. `Book.accessible_by(current_ability)`).
    # @param fieldset [Symbol, nil] which declared fieldset to use; defaults to
    #   `:index` (or every column when the model declares nothing).
    # @param layout [Symbol] the layout partial under `crud_components/layouts/`
    #   — `:table` ships; add your own (e.g. `:cards`) and pass its name.
    # @param query [CrudComponents::Query, false, nil] query mode: nil = auto
    #   (reads request params), a {Query} = manual (records already filtered),
    #   false = static (no filter row / sort links). See {Presenters::Collection}.
    # @param param_prefix [Symbol, nil] namespaces this collection's params so two
    #   auto collections can share one page.
    # @param actions [Boolean] render the actions column + toolbar (false to place
    #   them yourself with {#crud_actions}).
    # @param group_by [Symbol, nil] a column, belongs_to or enum to group rows
    #   under collapsible headers.
    # @return [ActiveSupport::SafeBuffer] the rendered HTML.
    def crud_collection(records, fieldset: nil, layout: :table, query: nil, param_prefix: nil,
                        actions: true, group_by: nil)
      presenter = Presenters::Collection.new(view: self, records: records, fieldset: fieldset,
                                             query: query, layout: layout, param_prefix: param_prefix,
                                             actions: actions, group_by: group_by)
      render "crud_components/layouts/#{presenter.layout}", collection: presenter
    end

    # One record as a definition list (or any layout partial you point `layout:`
    # at). Extend by creating your own partial — e.g. `crud_components/_card`
    # — and passing `layout: :card`.
    #
    # @param record [ActiveRecord::Base] the record to show.
    # @param fieldset [Symbol, nil] which fieldset to use; defaults to `:show`.
    # @param actions [Boolean] render the row actions (false to place them with
    #   {#crud_actions}).
    # @param layout [Symbol] the partial under `crud_components/` (`:record` ships).
    # @return [ActiveSupport::SafeBuffer] the rendered HTML.
    def crud_record(record, fieldset: nil, actions: true, layout: :record)
      presenter = Presenters::Record.new(view: self, record: record, fieldset: fieldset, actions: actions)
      render "crud_components/#{layout}", record_presenter: presenter
    end

    # A standalone labelled filter form (modal / sidebar) — separate from the
    # inline filter row a table renders.
    #
    # @param model [Class] the ActiveRecord model whose fields drive the form.
    # @param fieldset [Symbol, nil] which fieldset's filterable fields to offer.
    # @param query [CrudComponents::Query, nil] reuse an existing query's values;
    #   nil reads the request params.
    # @param param_prefix [Symbol, nil] namespaces the form's params.
    # @param layout [Symbol] the partial under `crud_components/` (`:filter` ships).
    # @return [ActiveSupport::SafeBuffer] the rendered HTML.
    def crud_filter(model, fieldset: nil, query: nil, param_prefix: nil, layout: :filter)
      presenter = Presenters::Filter.new(view: self, model: model, fieldset: fieldset,
                                         query: query, param_prefix: param_prefix)
      render "crud_components/#{layout}", filter: presenter
    end

    # A derived create/edit form. The gem renders; your controller saves using
    # the matching permit list ({CrudComponents.permitted_attributes}), so the
    # form and strong-params can't drift.
    #
    # @param record [ActiveRecord::Base] a new or persisted instance.
    # @param fieldset [Symbol, nil] which fieldset's fields to render; defaults to
    #   the form fieldset for the action.
    # @param action [Symbol, nil] `:new`/`:edit`; inferred from the record when nil.
    # @param url [String, nil] the form action URL; inferred from the record when nil.
    # @param method [Symbol, nil] the HTTP verb; inferred when nil.
    # @param layout [Symbol] the partial under `crud_components/` (`:form` ships).
    # @return [ActiveSupport::SafeBuffer] the rendered HTML.
    def crud_form(record, fieldset: nil, action: nil, url: nil, method: nil, layout: :form)
      presenter = Presenters::Form.new(view: self, record: record, fieldset: fieldset,
                                       action: action, url: url, method: method)
      render "crud_components/#{layout}", form: presenter
    end

    # The action buttons for a record (row actions) or a model class (collection
    # actions) — for manual placement when you render with `actions: false`.
    #
    # @param subject [ActiveRecord::Base, Class] a record (row actions) or the
    #   model class (collection actions). A relation is rejected — collection
    #   actions are model-level (`can?(:new, Book)`), so pass the class.
    # @param fieldset [Symbol, nil] which fieldset's actions to use; defaults to
    #   `:index` (collection) or `:show` (row).
    # @return [ActiveSupport::SafeBuffer] the rendered HTML.
    # @raise [ArgumentError] if given a relation.
    def crud_actions(subject, fieldset: nil)
      if subject.is_a?(ActiveRecord::Relation)
        raise ArgumentError,
              'crud_actions takes a record (row actions) or a model class (collection ' \
              "actions), not a relation — pass `#{subject.klass}`, not a scope."
      end
      model = subject.is_a?(Class) ? subject : subject.class
      structure = Structure.for(model)
      kind = subject.is_a?(Class) ? :collection : :row
      resolved_fieldset = structure.fieldset(fieldset || (kind == :collection ? :index : :show))
      presenter = Presenters::Actions.new(view: self, subject: subject, structure: structure,
                                          actions: structure.fieldset_actions(resolved_fieldset, on: kind))
      render 'crud_components/actions', actions: presenter
    end

    # ── utilities (used by the gem's partials; useful in apps too) ─────────

    # The display label for a record — its declared `label`, else a humanized guess.
    # @param record [ActiveRecord::Base]
    # @return [String]
    def crud_label(record)
      Structure.for(record.class).label_for(record, self)
    end

    # A Bootstrap-icon name (no library prefix — pair with css.icon_prefix) for a
    # filename, by extension: config.file_icons[ext], else config.file_fallback_icon.
    # Used by the attachment renderer's icon fallback; override that partial to
    # customize.
    #
    # @param filename [String, #to_s] the file name (or path) to derive from.
    # @return [String] the icon name.
    def crud_file_icon(filename)
      config = CrudComponents.config
      ext = File.extname(filename.to_s).delete('.').downcase
      config.file_icons.fetch(ext, config.file_fallback_icon)
    end

    # The canonical path to a record (its `show`, resolved by {RouteResolver}).
    # @param record [ActiveRecord::Base]
    # @param owner [ActiveRecord::Base, nil] the owner, for a nested route.
    # @return [String, nil] the path, or nil when none resolves.
    def crud_record_path(record, owner: nil)
      found = RouteResolver.record_path(self, record, owner: owner)
      found&.first
    end

    # The index a has_many cell links to: nested under the owner, else the
    # target's filtered index, else nil.
    # @param owner [ActiveRecord::Base] the record that owns the association.
    # @param field [CrudComponents::Fields::HasManyField] the association field.
    # @return [String, nil] the path, or nil when none resolves.
    def crud_association_index_path(owner, field)
      RouteResolver.collection_index_path(self, field.target, owner, field.name)
    end
  end
end
