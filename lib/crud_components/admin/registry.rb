module CrudComponents
  module Admin
    # Which models the admin administers, resolved once and memoized. The route
    # drawer, the sidebar and the controller all read from here.
    class Registry
      def initialize(config)
        @config = config
      end

      # Registered models, in sidebar/route order.
      def entries
        @entries ||= build
      end

      # The entry for a model class or model name, or nil when unregistered.
      def [](model)
        key = model.is_a?(Class) ? model.name : model.to_s
        index[key]
      end

      def registered?(model) = !self[model].nil?

      # Entries grouped for the sidebar: [group (nil = ungrouped), entries].
      def groups(list = entries)
        list.group_by(&:group).sort_by { |group, _| [group_rank(group), group.to_s] }
      end

      # Where a group sits in the configured order; unlisted groups come last.
      def group_rank(group)
        position = Array(config.groups).index { |name| name.to_s == group.to_s }
        position || Array(config.groups).size
      end

      def reload!
        @entries = nil
        @index = nil
        @except_names = nil
        self
      end

      private

      attr_reader :config

      def index
        @index ||= entries.to_h { |entry| [entry.name, entry] }
      end

      def build
        return explicit_entries if config.only

        discovered = candidates.reject { |model| excluded?(model) }
        sort(discovered.map { |model| Entry.new(model, admin_options(model) || {}) })
      end

      # `only` is a directive: the listed models are registered in the listed
      # order, whether or not discovery would have found them.
      def explicit_entries
        Array(config.only).filter_map do |name|
          model = constantize(name)
          next unless model && usable?(model) && admin_options(model) != false

          Entry.new(model, admin_options(model) || {})
        end
      end

      def candidates
        load_model_constants
        ActiveRecord::Base.descendants
      end

      # Resolves every constant under the model directories, and nothing else.
      # Deliberately not `Rails.application.eager_load!`: routes are drawn in
      # every process, including rake tasks and asset builds, which switch
      # eager loading off on purpose — and where an app's own initializers may
      # not have the credentials that eager loading would ask for.
      def load_model_constants
        return unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

        model_dirs.each do |dir|
          Dir.glob(File.join(dir, '**', '*.rb')).sort.each do |file|
            file.delete_prefix("#{dir}/").delete_suffix('.rb').camelize.safe_constantize
          end
        end
      end

      # The application's own model directories, and only those. An engine's
      # app/models holds the framework's own tables — loading Active Storage's
      # Blob, for one, builds the configured storage service on the spot, which
      # an asset build has no credentials for. Registering a model from an
      # engine is what `config.only` is for.
      def model_dirs
        Rails.application.config.paths['app/models'].existent
      end

      def excluded?(model)
        return true unless usable?(model)
        return true if internal?(model)
        return true if admin_options(model) == false
        return true if except_names.include?(model.name)
        return true if sti_subclass?(model) && own_admin_options(model).nil?

        false
      end

      # Anonymous and throwaway classes are skipped: a route and a controller
      # need a name that resolves back to the same class. Nothing here asks the
      # database — routes are drawn before the schema exists often enough (a
      # fresh checkout, a container that boots ahead of its migrations) that a
      # registry which quietly comes up empty is the worse failure.
      def usable?(model)
        return false unless model.is_a?(Class) && model.name
        return false if model.abstract_class?
        return false if model == ActiveRecord::Base

        model.name.safe_constantize.equal?(model)
      end

      def internal?(model)
        return true if model.name.include?('HABTM_')

        root = model.name.split('::').first
        config.excluded_namespaces.include?(root)
      end

      def sti_subclass?(model) = model.base_class != model

      # The `admin` declaration, read from the DSL block rather than from a
      # resolved Structure: routes are drawn before a model's columns can be
      # asked for (there may be no database, and resolving an attachment field
      # would build the storage service). Inherited from an STI parent.
      def admin_options(model)
        block = declaration_block(model)
        return nil unless block

        Builder.new(model, &block).admin_decl
      end

      # The options this very class declared, ignoring anything inherited.
      def own_admin_options(model)
        return nil unless own_declaration_block(model)

        admin_options(model)
      end

      def declaration_block(model)
        klass = model
        while klass.respond_to?(:instance_variable_defined?)
          block = own_declaration_block(klass)
          return block if block

          klass = klass.superclass
          break if klass.nil? || klass == ActiveRecord::Base
        end
        nil
      end

      def own_declaration_block(model)
        return nil unless model.instance_variable_defined?(:@_crud_structure_block)

        model.instance_variable_get(:@_crud_structure_block)
      end

      def except_names
        @except_names ||= Array(config.except).map { |name| name.is_a?(Class) ? name.name : name.to_s }
      end

      def constantize(name)
        model = name.is_a?(Class) ? name : name.to_s.safe_constantize
        model if model.respond_to?(:columns_hash)
      end

      def sort(list)
        list.sort_by { |entry| [group_rank(entry.group), entry.group.to_s, entry.label.to_s] }
      end


    end
  end
end
