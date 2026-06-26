module CrudComponents
  module Fields
    # The field flavor behind a {CrudComponents::DynamicColumn}: a column with no
    # row in the model's table. It renders like a ComputedField (value typed, or
    # `as:`), but the value comes from the column's resolver block rather than a
    # method on the record, and a `preload:` lambda primes a per-page cache so a
    # whole table costs one fetch, not one per row.
    #
    # Unlike the built-in fields — memoized on the immutable Structure and shared
    # across every request — a DynamicField is built fresh per `crud_collection`
    # call, so it may safely hold request state (the loaded cache). Filtering and
    # sorting work only through the column's `filter:`/`sort:` facets; without
    # them the column never reaches SQL, which keeps the query whitelist intact.
    class DynamicField < ComputedField
      # header:/header_actions: arrive via the column's options and are read by
      # Fields::Base#header / #header_actions / #custom_header? — the layout picks
      # them up through the Collection presenter, same as a declared attribute's.
      def initialize(column, model)
        super(column.name, model, column.options, column.facets)
        @value_block = column.value_block
        @preload_block = column.preload_block
        @loaded = nil
      end

      # Run the batch loader once over the page's records; the resolver then
      # reads per-record from whatever it returned. Called by the presenter just
      # before rendering, only for the columns that end up visible.
      def preload!(records)
        @loaded = @preload_block&.call(records)
        self
      end

      def value(record)
        return super unless @value_block

        @value_block.arity == 1 ? @value_block.call(record) : @value_block.call(record, @loaded)
      end

      # Never backed by a real DB column — keep column/nullable introspection
      # nil so nothing tries to read model.columns_hash[name].
      def column = nil
    end
  end
end
