# frozen_string_literal: true

class PublishersController < ApplicationController
  def index = @publishers = Publisher.all

  def show
    @publisher = find_publisher
  end

  # build_contact so the nested block has a record to render: without one it
  # draws nothing, and a publisher could never get a contact through the form.
  def new
    @publisher = Publisher.new
    @publisher.build_contact
  end

  def edit
    @publisher = find_publisher
  end

  def create
    @publisher = Publisher.new(publisher_params)
    if @publisher.save
      redirect_to @publisher, notice: 'Publisher created.'
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    @publisher = find_publisher
    if @publisher.update(publisher_params)
      redirect_to @publisher, notice: 'Publisher updated.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    find_publisher.destroy!
    redirect_to publishers_path, notice: 'Publisher deleted.'
  end

  private

  def find_publisher
    Publisher.find_by!(slug: params[:id])
  end

  def publisher_params
    params.require(:publisher).permit(*CrudComponents.permitted_attributes(Publisher, action: action_name.to_sym,
                                                                                      ability: self))
  end
end
