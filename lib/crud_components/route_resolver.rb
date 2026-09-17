# frozen_string_literal: true

module CrudComponents
  # Resolves derived actions and record links to routes: the most specific
  # conventional route first (association-scoped when the collection came
  # from an association), then the top-level route, then nil — a nil means
  # the button/link is omitted, never broken.
  #
  # A helper that exists is not enough: its route must serve the verb the link
  # uses, take no more arguments than it is given, and — for a nested
  # candidate — take the owner's key. `publisher_book_path` may belong to
  # update/destroy only, and `publisher_review_path` to an unrelated
  # `PublisherReview` resource.
  module RouteResolver
    module_function

    def action_path(view, action, record: nil, model: nil, owner: nil)
      return safe_block(view, record || model, action.path_block) if action.path_block

      if action.collection?
        collection_path(view, action, model, owner)
      else
        member_path(view, action, record, owner)
      end
    end

    # The host application's own page for a record — the same candidate logic,
    # resolved against `main_app` instead of the current route set. A declared
    # `app_path` block wins. nil when nothing resolves.
    def app_path(view, record)
      structure = Structure.for(record.class)
      if (block = structure.app_path_block)
        return safe_block(view, record, block)
      end

      return nil unless view.respond_to?(:main_app)

      try_helpers(view.main_app, member_candidates(nil, record, nil), verb: :get)
    end

    # The plain link to a record (label cells, association cells):
    # show route, then edit. Returns [path, kind] or nil.
    def record_path(view, record, owner: nil)
      path = try_helpers(view, member_candidates(nil, record, owner), verb: :get)
      return [path, :show] if path

      path = try_helpers(view, member_candidates('edit_', record, owner), verb: :get)
      path ? [path, :edit] : nil
    end

    # Whether the record has a plain (show) route — feeds the
    # ":show button only without a label link" rule.
    def show_path(view, record, owner: nil)
      try_helpers(view, member_candidates(nil, record, owner), verb: :get)
    end

    # The index a has_many "+n more" link points at:
    #   1. the nested index under the owner (publisher_books_path(publisher)),
    #   2. else the target's index filtered by the owner — but ONLY when the
    #      target actually has a filterable belongs_to back to the owner
    #      (publisher→books works; a habtm like author↔books does not, so we
    #      do not emit a link that would silently show everything),
    #   3. else nil (the renderer shows "+n more" as plain text).
    # `assoc_name` is the owner's reflection name (e.g. :books).
    def collection_index_path(view, target, owner, assoc_name)
      return nil unless owner

      key = target.model_name.route_key
      owner_key = owner.model_name.singular_route_key
      nested = "#{owner_key}_#{key}_path"
      if view.respond_to?(nested) && route_fits?(view, nested, [owner], verb: :get, owner: owner)
        return safe_url(view, nested, owner)
      end

      flat = "#{key}_path"
      return nil unless view.respond_to?(flat) && route_fits?(view, flat, [], verb: :get)

      filter = inverse_filter(target, owner, assoc_name)
      return nil unless filter

      safe_url(view, flat, **{ filter[:param] => filter[:value] })
    end

    # The target's belongs_to that mirrors the owner's collection (matched by
    # foreign key), if it is filterable — with the owner's identify_by value.
    def inverse_filter(target, owner, assoc_name)
      owner_reflection = owner.class.reflect_on_association(assoc_name)
      return nil unless owner_reflection&.foreign_key

      fk = owner_reflection.foreign_key.to_s
      inverse = target.reflect_on_all_associations(:belongs_to).find { |r| r.foreign_key.to_s == fk }
      return nil unless inverse

      field = Structure.for(target).field(inverse.name)
      return nil unless field.filterable?

      identify = Structure.for(owner.class).identify_by
      { param: inverse.name, value: owner.public_send(identify) }
    rescue CrudComponents::DefinitionError
      nil
    end

    # A path block naming a route helper that does not exist here — the same
    # page rendered under a mount that lacks it — yields nil, so the button is
    # omitted. Anything else the block gets wrong is the app's own error and
    # stays loud.
    def safe_block(view, subject, block)
      view.instance_exec(subject, &block)
    rescue ActionController::UrlGenerationError
      nil
    rescue NameError => e
      raise unless missing_route_helper?(e)

      nil
    end

    def missing_route_helper?(error)
      error.name.to_s.end_with?('_path', '_url')
    end

    def safe_url(view, helper, *, **kwargs)
      kwargs.empty? ? view.public_send(helper, *) : view.public_send(helper, *, **kwargs)
    rescue ActionController::UrlGenerationError, NoMethodError
      nil
    end

    def member_path(view, action, record, owner)
      prefix = { show: nil, destroy: nil, edit: 'edit_' }.fetch(action.name, "#{action.name}_")
      try_helpers(view, member_candidates(prefix, record, owner), verb: action.http_method)
    end

    def collection_path(view, action, model, owner)
      prefix = action.name == :new ? 'new_' : "#{action.name}_"
      key = action.name == :new ? model.model_name.singular_route_key : model.model_name.route_key
      candidates = []
      candidates << ["#{prefix}#{owner.model_name.singular_route_key}_#{key}_path", [owner], owner] if owner
      candidates << ["#{prefix}#{key}_path", []]
      try_helpers(view, candidates, verb: action.http_method)
    end

    def member_candidates(prefix, record, owner)
      key = record.model_name.singular_route_key
      candidates = []
      candidates << ["#{prefix}#{owner.model_name.singular_route_key}_#{key}_path", [owner, record], owner] if owner
      candidates << ["#{prefix}#{key}_path", [record]]
      candidates
    end

    # `helpers` is anything exposing route helpers — the view, or `main_app`.
    # Each candidate is [helper, args] or [helper, args, owner].
    def try_helpers(helpers, candidates, verb:)
      candidates.each do |helper, args, owner|
        next unless helpers.respond_to?(helper)
        next unless route_fits?(helpers, helper, args, verb: verb, owner: owner)

        begin
          return helpers.public_send(helper, *args)
        rescue ActionController::UrlGenerationError, NoMethodError
          next
        end
      end
      nil
    end

    # Whether the named route behind `helper` can take `args` for a `verb`
    # request. Leading parts beyond the arguments (a `scope ':locale'`) are
    # left to the url options, as the helper itself does. When the route set
    # cannot be inspected, the helper's existence has to do.
    def route_fits?(helpers, helper, args, verb:, owner: nil)
      routes = defining_route_set(helpers, helper)
      return true unless routes

      route = routes.named_routes.get(helper.to_s.delete_suffix('_path'))
      return true unless route

      parts = route.required_parts.map(&:to_s)
      return false if args.size > parts.size
      return false if owner && parts.none? { |part| part.start_with?("#{owner.model_name.singular_route_key}_") }

      serves_verb?(routes, route, verb.to_s.upcase)
    end

    # The named route answers the verb, or another route on the same path does
    # (only the first route drawn for a path carries the name).
    # Memoized per route object, so a redrawn route set starts afresh.
    def serves_verb?(routes, route, verb)
      return true if verb_matches?(route, verb)

      answers = (SIBLING_VERBS[route] ||= {})
      return answers[verb] if answers.key?(verb)

      spec = route.path.spec.to_s
      answers[verb] = routes.routes.any? { |other| other.path.spec.to_s == spec && verb_matches?(other, verb) }
    end

    SIBLING_VERBS = ObjectSpace::WeakMap.new
    private_constant :SIBLING_VERBS

    def verb_matches?(route, verb)
      route.verb.empty? || route.verb.split('|').include?(verb)
    end

    # The route set that owns the helper: the helpers' own, else the host
    # application's, which an engine's views forward unknown helpers to.
    def defining_route_set(helpers, helper)
      sets = [route_set(helpers)]
      sets << route_set(helpers.main_app) if helpers.respond_to?(:main_app)
      sets.compact.find { |routes| routes.named_routes.route_defined?(helper) }
    end

    def route_set(helpers)
      return nil unless helpers.respond_to?(:_routes, true)

      routes = helpers.send(:_routes)
      routes if routes.respond_to?(:named_routes)
    end
  end
end
