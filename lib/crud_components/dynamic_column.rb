module CrudComponents
  # A column whose data lives *outside* the model's own table — a user-defined
  # property kept in a separate store (definition + value tables, a JSONB blob,
  # an external API). The model knows nothing about it; you build one per request
  # from wherever your custom properties live and hand it to `crud_collection`
  # via `extra_columns:`.
  #
  #   CrudComponents::DynamicColumn.new(:priority,
  #     label: 'Priority', as: :number,
  #     if:      -> { can?(:read, prop) },           # same gate as a field's if:
  #     preload: ->(records) {                       # batch-load once per page (no N+1)
  #       PropertyValue.where(definition: prop, subject: records).index_by(&:subject_id)
  #     },
  #     sort:   ->(scope, dir) { ... },              # optional — omit for display-only
  #     filter: ->(scope, value) { ... }) { |record, loaded| loaded[record.id]&.value }
  #
  # The block is the value resolver: `|record|` or `|record, loaded|`, where
  # `loaded` is whatever `preload:` returned. It returns a plain value that the
  # `as:` renderer (or, with no `as:`, the value's type) displays — exactly like
  # a computed field. `filter:`/`sort:` are the same facet blocks the DSL takes;
  # supply them only when the data is reachable in SQL, otherwise the column is
  # display-only and never reaches the query layer.
  #
  # A dynamic column often *is* a domain object (a mail, a resource), so its
  # header can carry a link and its own bulk actions, rendered in the `<th>`:
  #
  #   CrudComponents::DynamicColumn.new(:mail_42,
  #     label:  'Welcome mail',
  #     header: -> { link_to mail.name, mail },             # HTML-safe String or a view-context block
  #     header_actions: [                                   # the same Action API as row/collection actions
  #       CrudComponents::Action.new(:send_all, icon: 'send', method: :post) { send_all_path(mail) },
  #       CrudComponents::Action.new(:unschedule_all, method: :post) { unschedule_all_path(mail) }
  #     ],
  #     preload: ->(records) { ... }) { |record, loaded| loaded[record.id] }
  #
  # `header:` replaces the plain `human_name` text (a String is rendered as-is —
  # mark it `html_safe` if it carries markup; a block is `instance_exec`ed in the
  # view, so it may call `link_to` and friends). `header_actions:` renders after
  # the header; a non-GET action (`method: :post`) becomes a `button_to` form,
  # not a link, exactly like a collection/row action.
  class DynamicColumn
    attr_reader :name, :options, :facets, :preload_block, :value_block,
                :header, :header_actions

    # Keys consumed here; everything else (as:, if:, label:, unit:, digits:, …)
    # flows into `options` just like a declared attribute's options.
    FACET_KEYS = %i[filter sort render].freeze

    def initialize(name, preload: nil, header: nil, header_actions: nil, **opts, &value_block)
      @name = name.to_sym
      @value_block = value_block
      @preload_block = preload
      @header = header
      @header_actions = Array(header_actions)
      @facets = opts.slice(*FACET_KEYS).compact
      @options = opts.except(*FACET_KEYS)
    end

    # A request-scoped field bound to `model`. Not memoized on the Structure, so
    # it may carry the per-request value cache (see Fields::DynamicField).
    def to_field(model)
      Fields::DynamicField.new(self, model)
    end
  end
end
