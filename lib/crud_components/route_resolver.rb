module CrudComponents
  # Resolves derived actions and record links to routes: the most specific
  # conventional route first (association-scoped when the collection came
  # from an association), then the top-level route, then nil — a nil means
  # the button/link is omitted, never broken.
  module RouteResolver
    module_function

    def action_path(view, action, record: nil, model: nil, owner: nil)
      if action.path_block
        subject = record || model
        return view.instance_exec(subject, &action.path_block)
      end

      if action.collection?
        collection_path(view, action, model, owner)
      else
        member_path(view, action, record, owner)
      end
    end

    # The plain link to a record (label cells, association cells):
    # show route, then edit. Returns [path, kind] or nil.
    def record_path(view, record, owner: nil)
      path = try_helpers(view, member_candidates(nil, record, owner))
      return [path, :show] if path

      path = try_helpers(view, member_candidates('edit_', record, owner))
      path ? [path, :edit] : nil
    end

    # Whether the record has a plain (show) route — feeds the
    # ":show button only without a label link" rule.
    def show_path(view, record, owner: nil)
      try_helpers(view, member_candidates(nil, record, owner))
    end

    # The index a has_many "+n more" link points at: the nested index under
    # the owner (publisher_books_path(publisher)) if it resolves, else the
    # target's index filtered by the owner (books_path(publisher: owner)),
    # else nil. `assoc_name` is the owner's reflection name.
    def collection_index_path(view, target, owner, assoc_name)
      return nil unless owner

      key = target.model_name.route_key
      owner_key = owner.model_name.singular_route_key
      nested = "#{owner_key}_#{key}_path"
      return view.public_send(nested, owner) if view.respond_to?(nested)

      flat = "#{key}_path"
      if view.respond_to?(flat)
        param = owner.class.model_name.param_key
        begin
          return view.public_send(flat, param => owner.to_param)
        rescue ActionController::UrlGenerationError, NoMethodError
          return nil
        end
      end
      nil
    end

    def member_path(view, action, record, owner)
      prefix = { show: nil, destroy: nil, edit: 'edit_' }.fetch(action.name, "#{action.name}_")
      try_helpers(view, member_candidates(prefix, record, owner))
    end

    def collection_path(view, action, model, owner)
      prefix = action.name == :new ? 'new_' : "#{action.name}_"
      key = action.name == :new ? model.model_name.singular_route_key : model.model_name.route_key
      candidates = []
      candidates << ["#{prefix}#{owner.model_name.singular_route_key}_#{key}_path", [owner]] if owner
      candidates << ["#{prefix}#{key}_path", []]
      try_helpers(view, candidates)
    end

    def member_candidates(prefix, record, owner)
      key = record.model_name.singular_route_key
      candidates = []
      candidates << ["#{prefix}#{owner.model_name.singular_route_key}_#{key}_path", [owner, record]] if owner
      candidates << ["#{prefix}#{key}_path", [record]]
      candidates
    end

    def try_helpers(view, candidates)
      candidates.each do |helper, args|
        next unless view.respond_to?(helper)

        begin
          return view.public_send(helper, *args)
        rescue ActionController::UrlGenerationError, NoMethodError
          next
        end
      end
      nil
    end
  end
end
