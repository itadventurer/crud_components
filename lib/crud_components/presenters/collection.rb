module CrudComponents
  module Presenters
    # The single `collection` local every layout partial receives.
    #
    # query: nil    → auto mode (build from request params and apply)
    # query: Query  → manual mode (records arrive already filtered)
    # query: false  → static (no filter row, no sort links)
    class Collection < Base
      attr_reader :model, :structure, :fieldset, :query, :layout, :param_prefix, :owner

      def initialize(view:, records:, fieldset: nil, query: nil, layout: :table,
                     param_prefix: nil, actions: true)
        super(view: view)
        relation = records.is_a?(Class) ? records.all : records
        @model = relation.klass
        @structure = Structure.for(@model)
        @owner = relation.respond_to?(:proxy_association) ? relation.proxy_association.owner : nil
        @layout = layout
        @param_prefix = param_prefix
        @actions_enabled = actions

        case query
        when false
          @static = true
          @fieldset = @structure.fieldset(fieldset || :index)
        when nil
          @fieldset = @structure.fieldset(fieldset || :index)
          @query = Query.new(@model, view.request.query_parameters, fieldset: @fieldset,
                             ability: ability, param_prefix: param_prefix)
          relation = @query.apply(relation)
        else
          @query = query
          @fieldset = fieldset ? @structure.fieldset(fieldset) : query.fieldset
          @param_prefix = query.param_prefix
        end

        @relation = eager_load(relation)
      end

      def static? = !!@static
      def surface = :collection

      def records
        @records ||= @relation.to_a
      end

      def fields
        @fields ||= structure.fieldset_fields(fieldset).select { |f| f.permitted?(permission_context) }
      end

      # ── cells ────────────────────────────────────────────────────────────
      def cell(field, record)
        html = render_cell(field, record, surface: :collection, cell_context: cell_context)
        if label_link_field?(field) && (path = record_link(record))
          view.link_to(html, path, class: css.record_link, data: { turbo_action: 'advance' })
        else
          html
        end
      end

      # Click-to-filter context for value renderers — only when this
      # collection actually has a live query.
      def cell_context
        return nil if static? || query.nil?

        @cell_context ||= CellContext.new(view: view, query: query)
      end

      def label_link_field?(field)
        field.name == structure.label_field_name
      end

      def record_link(record)
        @record_links ||= {}
        return @record_links[record.id] if @record_links.key?(record.id)

        found = RouteResolver.record_path(view, record, owner: owner)
        @record_links[record.id] = found&.first
      end

      def label_link_present?(record)
        fields.any? { |f| label_link_field?(f) } && record_link(record).present?
      end

      # ── filtering ────────────────────────────────────────────────────────
      def filterable?
        !static? && query && filter_fields.any?
      end

      def filter_fields
        @filter_fields ||= static? ? [] : query.filter_fields
      end

      def filterable_field?(field)
        filter_fields.include?(field)
      end

      def filter_form_id
        suffix = param_prefix ? "_#{param_prefix}" : ''
        "crud_filter_#{model.model_name.plural}#{suffix}"
      end

      # ── header search (?q=) and reset ──────────────────────────────────────
      def searchable?
        !static? && query && query.searchable?
      end

      def search_param_name
        query.param_name('q')
      end

      def search_value
        query&.value('q')
      end

      def filtered?
        !static? && query&.active?
      end

      # Whether the toolbar (search + collection actions) has anything to show —
      # lets a layout skip an empty header row.
      def show_toolbar?
        searchable? || collection_actions&.any?
      end

      # Reset clears *this* collection's filter/search/sort/page params and
      # keeps everyone else's (other prefixes, the page's own params).
      def reset_url
        kept = view.request.query_parameters.reject { |key, _| own_param_keys.include?(key) }
        kept.any? ? "#{view.request.path}?#{kept.to_query}" : view.request.path
      end

      # Hidden inputs for the filter form: keep this collection's sort and
      # every param that belongs to someone else (other prefixes, the page's
      # own params). Drop our own filter/search params — the controls
      # themselves resubmit those.
      def preserved_params
        own = filter_fields.flat_map { |f| [pn(f.name.to_s), pn("#{f.name}_geq"), pn("#{f.name}_leq")] }
        own += [pn('q'), pn('page'), pn('per')]
        view.request.query_parameters.reject { |key, _| own.include?(key) }
      end

      # Every param key this collection owns (for reset).
      def own_param_keys
        keys = filter_fields.flat_map { |f| [pn(f.name.to_s), pn("#{f.name}_geq"), pn("#{f.name}_leq")] }
        keys + %w[q sort dir page per].map { |k| pn(k) }
      end

      # ── sorting ──────────────────────────────────────────────────────────
      def sortable_field?(field)
        !static? && query && query.sortable_fields.include?(field)
      end

      def sort_url(field)
        current, dir = query.sort_state
        next_dir = current == field.name.to_s && dir == 'asc' ? 'desc' : 'asc'
        params = view.request.query_parameters.merge(pn('sort') => field.name.to_s, pn('dir') => next_dir)
        "#{view.request.path}?#{params.to_query}"
      end

      def sort_indicator(field)
        current, dir = query&.sort_state
        return '' unless current == field.name.to_s

        dir == 'desc' ? ' ▼' : ' ▲'
      end

      # ── pagination ─────────────────────────────────────────────────────────
      # We render a footer pager only when the relation handed to us is already
      # paginated — i.e. the host called `.page` (kaminari / will_paginate, which
      # decorate the relation). The gem never paginates on its own: no records
      # arrive limited unless you asked for it. pagy keeps its state in a
      # separate object, not on the relation, so it can't be detected here —
      # render `pagy_nav` yourself.
      def paginated?
        @relation.respond_to?(:current_page) && @relation.respond_to?(:total_pages)
      end

      # Whether to draw the footer at all — a single page needs no pager.
      def show_pager? = paginated? && total_pages > 1

      def current_page = @relation.current_page
      def total_pages  = @relation.total_pages
      def total_count  = @relation.total_count

      # The underlying (possibly paginated) relation, for custom layouts that
      # would rather drive their own pager — e.g. hand it to kaminari's
      # `paginate` helper instead of rendering the gem's _pager.
      def page_scope = @relation

      # A URL for page n that keeps this collection's filters/search/sort and
      # every other collection's params (only our own `page` changes) — so the
      # pager composes with everything and respects `param_prefix:`.
      def page_url(n)
        params = view.request.query_parameters.merge(pn('page') => n)
        "#{view.request.path}?#{params.to_query}"
      end

      # Page numbers to show, with :gap markers for elided ranges:
      # [1, :gap, 4, 5, 6, :gap, 10]. Always includes first/last and a window
      # around the current page.
      def pager_pages(window: 2)
        return [] if total_pages <= 1

        shown = ([1, total_pages] + ((current_page - window)..(current_page + window)).to_a)
                .select { |p| p >= 1 && p <= total_pages }.uniq.sort
        shown.each_with_index.flat_map do |p, i|
          (i.positive? && p - shown[i - 1] > 1) ? [:gap, p] : [p]
        end
      end

      # ── actions ──────────────────────────────────────────────────────────
      def actions_column?
        @actions_enabled && (custom_actions_partial.present? || row_action_definitions.any?)
      end

      def custom_actions_partial
        fieldset.custom_actions_partial
      end

      def row_actions(record)
        Actions.new(view: view, subject: record, structure: structure,
                    actions: row_action_definitions, owner: owner,
                    suppress_show: label_link_present?(record))
      end

      def collection_actions
        return nil unless @actions_enabled

        @collection_actions ||= Actions.new(view: view, subject: model, structure: structure,
                                            actions: structure.fieldset_actions(fieldset, on: :collection),
                                            owner: owner)
      end

      def columns_count
        fields.size + (actions_column? ? 1 : 0)
      end

      private

      def row_action_definitions
        @row_action_definitions ||= structure.fieldset_actions(fieldset, on: :row)
      end

      def pn(key)
        query ? query.param_name(key) : key
      end

      def eager_load(relation)
        return relation unless relation.is_a?(ActiveRecord::Relation)

        names = fields.filter_map(&:eager_load_name)
        names.any? ? relation.includes(*names) : relation
      end
    end
  end
end
