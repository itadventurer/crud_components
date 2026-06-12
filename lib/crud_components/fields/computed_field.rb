module CrudComponents
  module Fields
    # A name Rails doesn't know: a public model method (rendered by its value
    # type) or a declared render block. Query behavior only through facets —
    # a Ruby-computed value has no SQL meaning until a facet gives it one.
    class ComputedField < Base
      def renderer(record = nil)
        return options[:as] if options[:as]
        return nil if render_block

        record ? renderer_for_value(value(record)) : :string
      end

      def default_renderer = :string

      def value(record)
        render_block ? nil : record.public_send(name)
      end

      private

      def renderer_for_value(value)
        case value
        when Numeric then :number
        when Date then :date
        when Time, DateTime then :datetime
        when true, false then :boolean
        when Hash, Array then :json
        else :string
        end
      end
    end
  end
end
