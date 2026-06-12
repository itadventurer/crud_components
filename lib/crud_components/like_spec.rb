module CrudComponents
  # The declarative mini-language shared by `filter like:` and `search_in`:
  # case-insensitive contains across columns, joining associations as needed.
  #
  #   :title                       own column
  #   %i[title subtitle]           several own columns, OR-combined
  #   { authors: %i[name email] }  join, explicit columns
  #   :publisher                   join, delegate to Publisher's search_in
  #   { user: :address }           nested join, delegate to Address
  #
  # Specs never contain SQL strings; conditions are built through Arel with
  # LIKE wildcards escaped, so they are parameterized end to end.
  module LikeSpec
    MAX_DEPTH = 5 # guards against search_in delegation cycles

    module_function

    def apply(scope, spec, value)
      model = scope.respond_to?(:model) ? scope.model : scope
      entries = expand(model, spec)
      return scope if entries.empty?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
      condition = entries.map { |entry| entry.arel_condition(pattern) }.reduce(:or)
      joins = entries.filter_map(&:join_fragment).reduce({}) { |acc, j| deep_merge(acc, j) }

      scope = scope.left_joins(joins) unless joins.empty?
      scope.where(condition).distinct
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

    # Resolves a spec into flat [path, klass, column] entries, expanding
    # association names without columns through the target's search_in spec.
    def expand(model, spec, path = [], depth = 0)
      raise DefinitionError, "search_in/like delegation deeper than #{MAX_DEPTH} levels " \
                             "starting at #{model} — most likely a delegation cycle" if depth > MAX_DEPTH

      Array.wrap(spec).flat_map do |item|
        case item
        when Symbol, String then expand_name(model, item.to_sym, path, depth)
        when Hash then item.flat_map { |assoc, sub| expand_assoc(model, assoc.to_sym, sub, path, depth) }
        else
          raise DefinitionError, "invalid like-spec element #{item.inspect} for #{model} — " \
                                 'use column symbols, association symbols, or { assoc => columns } hashes'
        end
      end
    end

    def expand_name(model, name, path, depth)
      if model.columns_hash.key?(name.to_s)
        [Entry.new(path, model, name)]
      elsif (reflection = model.reflect_on_association(name))
        delegate(model, reflection, path, depth)
      else
        raise DefinitionError, "like-spec references '#{name}', which is neither a column nor " \
                               "an association of #{model}"
      end
    end

    def expand_assoc(model, assoc, sub, path, depth)
      reflection = model.reflect_on_association(assoc)
      raise DefinitionError, "like-spec references association '#{assoc}', " \
                             "which #{model} does not have" unless reflection

      expand(reflection.klass, sub, path + [assoc], depth + 1)
    end

    # Association name without columns: use the target model's search_in spec.
    def delegate(model, reflection, path, depth)
      target = reflection.klass
      target_spec = Structure.for(target).search_in_spec
      if target_spec.nil?
        raise DefinitionError, "cannot delegate like-spec to #{model}##{reflection.name}: " \
                               "#{target}'s search_in is a custom block — spell the columns out, " \
                               "e.g. { #{reflection.name}: %i[...] }"
      end

      expand(target, target_spec, path + [reflection.name], depth + 1)
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
