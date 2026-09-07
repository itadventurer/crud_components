# frozen_string_literal: true

module CrudComponents
  module Admin
    # The mount root: what there is to administer.
    class DashboardController < ApplicationController
      def show
        @counts = admin_entries.to_h { |entry| [entry.name, admin_scope(entry).count] } if admin_config.counts
      end
    end
  end
end
