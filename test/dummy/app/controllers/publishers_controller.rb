class PublishersController < ApplicationController
  def index; end

  def show
    @publisher = Publisher.find_by!(slug: params[:id])
  end
end
