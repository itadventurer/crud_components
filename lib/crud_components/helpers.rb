module CrudComponents
  # The everyday API. Included into ActionView by the engine.
  module Helpers
    # A set of records. `records` may be a relation or a model class
    # (sugar for its `all`). See Presenters::Collection for the query modes.
    def crud_collection(records, fieldset: nil, as: :table, query: nil, param_prefix: nil, actions: true)
      presenter = Presenters::Collection.new(view: self, records: records, fieldset: fieldset,
                                             query: query, layout: as, param_prefix: param_prefix,
                                             actions: actions)
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

    # The action buttons of a record (row actions) or a model class
    # (collection actions) — for manual placement with `actions: false`.
    def crud_actions(subject, fieldset: nil)
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
