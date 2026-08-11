module CrudComponents
  module Admin
    # The mount root: what there is to administer.
    class DashboardController < ApplicationController
      def show
        @entries = admin_registry.entries
      end
    end
  end
end
