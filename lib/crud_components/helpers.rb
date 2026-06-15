module CrudComponents
  # The everyday API. Included into ActionView by the engine.
  module Helpers
    # A set of records. `records` is an ActiveRecord relation (e.g. `Book.all`,
    # `@books`, or an authorized scope like `Book.accessible_by(current_ability)`)
    # — pass a scope, not a model class, so your authorization and any
    # pre-scoping apply before the gem renders. See Presenters::Collection for
    # the query modes.
    def crud_collection(records, fieldset: nil, as: :table, query: nil, param_prefix: nil,
                        actions: true, group_by: nil)
      presenter = Presenters::Collection.new(view: self, records: records, fieldset: fieldset,
                                             query: query, layout: as, param_prefix: param_prefix,
                                             actions: actions, group_by: group_by)
      render "crud_components/layouts/#{presenter.layout}", collection: presenter
    end

    # One record as a definition list.
    def crud_record(record, fieldset: nil, actions: true)
      presenter = Presenters::Record.new(view: self, record: record, fieldset: fieldset, actions: actions)
      render 'crud_components/record', record_presenter: presenter
    end

    # A standalone labelled filter form (modal / sidebar).
    def crud_filter(model, fieldset: nil, query: nil, param_prefix: nil)
      presenter = Presenters::Filter.new(view: self, model: model, fieldset: fieldset,
                                         query: query, param_prefix: param_prefix)
      render 'crud_components/filter', filter: presenter
    end

    # A derived create/edit form. `record` is an instance (new or persisted).
    # The gem renders; your controller saves using the matching permit list
    # (CrudComponents.permitted_attributes / Model.crud_attribute_names).
    def crud_form(record, fieldset: nil, action: nil, url: nil, method: nil)
      presenter = Presenters::Form.new(view: self, record: record, fieldset: fieldset,
                                       action: action, url: url, method: method)
      render 'crud_components/form', form: presenter
    end

    # The action buttons of a record (row actions) or a model class (collection
    # actions) — for manual placement with `actions: false`. A relation is not a
    # subject here: collection actions are model-level (`can?(:new, Book)`), so
    # pass the class, not a scope.
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
    def crud_label(record)
      Structure.for(record.class).label_for(record, self)
    end

    # A Bootstrap-icon name (no library prefix — pair with css.icon_prefix) for
    # a filename, by extension: a filetype glyph for common types, a generic
    # file icon otherwise. Used by the attachment renderer's icon fallback;
    # override that partial to customize.
    FILE_ICONS = {
      pdf: 'filetype-pdf', doc: 'filetype-doc', docx: 'filetype-docx',
      xls: 'filetype-xls', xlsx: 'filetype-xlsx', csv: 'filetype-csv',
      ppt: 'filetype-ppt', pptx: 'filetype-pptx', txt: 'filetype-txt',
      json: 'filetype-json', xml: 'filetype-xml', yml: 'filetype-yml', yaml: 'filetype-yml',
      md: 'filetype-md', html: 'filetype-html', zip: 'file-earmark-zip'
    }.freeze

    def crud_file_icon(filename)
      ext = File.extname(filename.to_s).delete('.').downcase.to_sym
      FILE_ICONS.fetch(ext, 'file-earmark-text')
    end

    def crud_record_path(record, owner: nil)
      found = RouteResolver.record_path(self, record, owner: owner)
      found&.first
    end

    # The index a has_many cell links to: nested under the owner, else the
    # target's filtered index, else nil. `field` is the HasManyField.
    def crud_association_index_path(owner, field)
      RouteResolver.collection_index_path(self, field.target, owner, field.name)
    end
  end
end
