module CrudComponents
  # The declarative mini-language shared by `filter like:` and `search_in`:
  # case-insensitive contains across columns, joining associations as needed.
  #
  #   :title                       own column
  #   %i[title subtitle]           several own columns, OR-combined
  #   { authors: %i[name email] }  join, explicit columns
  #   :publisher                   join, search Publisher's label (what you see)
  #   { user: :address }           nested join, search Address's label
  #
  # Specs never contain SQL strings; conditions are built through Arel with
  # LIKE wildcards escaped, so they are parameterized end to end.
  module LikeSpec
    module_function

    def apply(scope, spec, value)
      model = scope.respond_to?(:model) ? scope.model : scope
      entries = expand(model, spec)
      return scope if entries.empty?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
      condition = entries.map { |entry| entry.arel_condition(pattern) }.reduce(:or)
      joins = entries.filter_map(&:join_fragment).reduce({}) { |acc, j| deep_merge(acc, j) }

      return scope.where(condition) if joins.empty?

      # A join can multiply rows, so the match has to be de-duplicated. We do it
      # with an id subquery rather than SELECT DISTINCT: DISTINCT compares every
      # selected column, which Postgres can't do for a json (or other
      # non-comparable) column the scope happens to select — it raises "could not
      # identify an equality operator for type json". The subquery sidesteps that
      # and keeps the join (and its rows) out of the outer query entirely.
      key = model.arel_table[model.primary_key]
      scope.where(key.in(model.left_joins(joins).where(condition).select(key).arel))
    end

    Entry = Struct.new(:path, :klass, :column) do
      # escape '\' must be explicit: sanitize_sql_like escapes with a
      # backslash, which is not the default LIKE escape char on SQLite.
      def arel_condition(pattern)
        Arel::Table.new(klass.table_name)[column].matches(pattern, '\\')
      end

      def join_fragment
        return nil if path.empty?

        path.reverse.reduce(nil) { |inner, assoc| inner ? { assoc => inner } : assoc }
      end
    end

    # Resolves a spec into flat [path, klass, column] entries. A bare
    # association name resolves to the target's label column — the text you
    # actually see in that association's cell — so it can never reach a
    # target's hidden columns (passwords, tokens, …) and there is no
    # search_in chain to form a cycle.
    def expand(model, spec, path = [])
      Array.wrap(spec).flat_map do |item|
        case item
        when Symbol, String then expand_name(model, item.to_sym, path)
        when Hash then item.flat_map { |assoc, sub| expand_assoc(model, assoc.to_sym, sub, path) }
        else
          raise DefinitionError, "invalid like-spec element #{item.inspect} for #{model} — " \
                                 'use column symbols, association symbols, or { assoc => columns } hashes'
        end
      end
    end

    def expand_name(model, name, path)
      if model.columns_hash.key?(name.to_s)
        [Entry.new(path, model, name)]
      elsif (reflection = model.reflect_on_association(name))
        delegate(model, reflection, path)
      else
        raise DefinitionError, "like-spec references '#{name}', which is neither a column nor " \
                               "an association of #{model}"
      end
    end

    # Explicit nesting ({ assoc => columns }) — spell the target's columns out.
    def expand_assoc(model, assoc, sub, path)
      reflection = model.reflect_on_association(assoc)
      raise DefinitionError, "like-spec references association '#{assoc}', " \
                             "which #{model} does not have" unless reflection

      expand(reflection.klass, sub, path + [assoc])
    end

    # Association name without columns: search the target's label column — the
    # name shown in its cell ("search what you see"). A block/computed label has
    # no single column to match, so ask for the columns explicitly.
    def delegate(model, reflection, path)
      target = reflection.klass
      label = Structure.for(target).label_field_name
      if label.nil?
        raise DefinitionError, "cannot search #{model}##{reflection.name} by label: " \
                               "#{target}'s label is a custom block, not a column — spell the columns out, " \
                               "e.g. { #{reflection.name}: %i[...] }"
      end

      [Entry.new(path + [reflection.name], target, label)]
    end

    def deep_merge(left, right)
      normalize = ->(j) { j.is_a?(Hash) ? j : { j => {} } }
      l = normalize.call(left)
      normalize.call(right).each do |key, value|
        l[key] = l.key?(key) ? deep_merge(l[key], value) : value
      end
      l
    end
  end
end
