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
    # @param extra_columns [Array<CrudComponents::DynamicColumn>, nil] user-defined
    #   columns whose data lives outside the model's table (custom properties from
    #   a separate store, JSONB, an API). Appended after the declared columns and
    #   subject to the same `if:` permission gate; filter/sort only when the column
    #   supplies those facets.
    # @param visible [Array<Symbol>, nil] the default ordered subset of columns to
    #   show (e.g. a persisted per-user preference). The `?cols=` param a column
    #   picker submits takes precedence over it.
    # @param column_picker [Boolean] render the column-picker control in the toolbar
    #   (lets a user hide/reorder the columns they may see; submits `?cols=` to the
    #   same URL, like sort/filter).
    # @return [ActiveSupport::SafeBuffer] the rendered HTML.
    def crud_collection(records, fieldset: nil, layout: :table, query: nil, param_prefix: nil,
                        actions: true, group_by: nil, extra_columns: nil, visible: nil,
                        column_picker: false)
      presenter = Presenters::Collection.new(view: self, records: records, fieldset: fieldset,
                                             query: query, layout: layout, param_prefix: param_prefix,
                                             actions: actions, group_by: group_by,
                                             extra_columns: extra_columns, visible: visible,
                                             column_picker: column_picker)
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
    # @param visible [Array<Symbol>, nil] narrow/order the shown fields (e.g. from a
    #   column picker placed on the page); the `?cols=` param overrides it.
    # @param param_prefix [Symbol, nil] namespaces the `?cols=` param this view reads
    #   (match it to the picker's `param_prefix:`).
    # @param extra_columns [Array<CrudComponents::DynamicColumn>, nil] user-defined
    #   columns whose data lives outside the model's table, shown as extra rows
    #   (same as {#crud_collection}'s `extra_columns:`, for a detail view).
    # @return [ActiveSupport::SafeBuffer] the rendered HTML.
    def crud_record(record, fieldset: nil, actions: true, layout: :record, visible: nil, param_prefix: nil,
                    extra_columns: nil)
      presenter = Presenters::Record.new(view: self, record: record, fieldset: fieldset, actions: actions,
                                         visible: visible, param_prefix: param_prefix, extra_columns: extra_columns)
      render "crud_components/#{layout}", record_presenter: presenter
    end

    # A standalone column picker — the same gear-and-checklist the table renders in
    # its header, but placed wherever you like (e.g. above a `crud_record` detail
    # view). It submits `?cols[]=` to `url` (the current page by default), so a
    # `crud_collection`/`crud_record` on the target page picks it up via `visible:`
    # or the param directly. Persist the choice with {CrudComponents.selected_columns}.
    #
    # @param subject [ActiveRecord::Relation, Class, ActiveRecord::Base] anything the
    #   columns belong to — a scope, the model class, or a record.
    # @param fieldset [Symbol, nil] which fieldset's fields to offer (e.g. `:show`).
    # @param extra_columns [Array<CrudComponents::DynamicColumn>, nil] dynamic columns
    #   to include in the choices.
    # @param visible [Array<Symbol>, nil] the current selection (pre-ticks the boxes).
    # @param url [String, nil] where the picker form submits; defaults to the current path.
    # @param param_prefix [Symbol, nil] namespaces the `?cols=` param.
    # @return [ActiveSupport::SafeBuffer] the rendered HTML.
    def crud_column_picker(subject, fieldset: nil, extra_columns: nil, visible: nil, url: nil, param_prefix: nil)
      relation = if subject.respond_to?(:klass) then subject
                 elsif subject.is_a?(Class) then subject.all
                 else subject.class.all
                 end
      presenter = Presenters::Collection.new(view: self, records: relation, fieldset: fieldset, query: nil,
                                             extra_columns: extra_columns, visible: visible,
                                             param_prefix: param_prefix, actions: false, column_picker: true)
      render 'crud_components/column_picker', collection: presenter, url: (url || request.path)
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

    # The label for an associated record in an association column: a per-column
    # `label:` callable (`attribute :order, label: ->(o) { o.full_title(short: true) }`)
    # when given, else the target's default {#crud_label}. Used by the
    # association / association_list renderers so a column can re-title the
    # associated record for its context while keeping the nil-safe link.
    # @param field [CrudComponents::Fields::Base] the association field.
    # @param record [ActiveRecord::Base] the associated record.
    # @return [String]
    def crud_association_label(field, record)
      callable = field.options[:label]
      callable.respond_to?(:call) ? callable.call(record) : crud_label(record)
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

    # Inline the gem's stylesheet (the column-picker float styles) as a <style>
    # tag — drop `<%= crud_components_styles %>` once in your layout <head>. This
    # is the pipeline-agnostic way to load it: it needs no asset compilation, so
    # it works the same under cssbundling/sass, importmap, sprockets or propshaft.
    # Hosts whose pipeline serves engine assets can instead link the same file
    # with `stylesheet_link_tag "crud_components"`.
    def crud_components_styles
      nonce = content_security_policy_nonce if respond_to?(:content_security_policy_nonce)
      tag.style(CrudComponents.bundled_css.html_safe, type: 'text/css', nonce: nonce)
    end
  end
end
