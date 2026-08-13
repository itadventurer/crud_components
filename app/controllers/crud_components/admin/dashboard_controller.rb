module CrudComponents
  module Admin
    # The mount root: what there is to administer.
    class DashboardController < ApplicationController
      def show
        @entries = admin_registry.entries.select { |entry| CrudComponents::Admin.routed?(entry) }
      end
    end
  end
end
