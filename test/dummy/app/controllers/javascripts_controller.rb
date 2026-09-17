# frozen_string_literal: true

# Serves Stimulus controllers straight from the install generator's templates,
# so the playground runs the file an app copies in.
class JavascriptsController < ApplicationController
  TEMPLATES = File.expand_path('../../../../lib/generators/crud_components/install/templates', __dir__)
  SERVED = %w[crud_value_filter_controller].freeze

  # Loaded by a module script; the file is the gem's public source.
  skip_forgery_protection only: :show

  def show
    name = SERVED.find { |served| served == params[:name] }
    return head :not_found unless name

    send_file File.join(TEMPLATES, "#{name}.js"), type: 'text/javascript', disposition: 'inline'
  end
end
