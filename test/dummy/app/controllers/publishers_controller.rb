class PublishersController < ApplicationController
  def index = @publishers = Publisher.all

  def show
    @publisher = find_publisher
  end

  def new
    @publisher = Publisher.new
  end

  def create
    @publisher = Publisher.new(publisher_params)
    if @publisher.save
      redirect_to @publisher, notice: 'Publisher created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @publisher = find_publisher
  end

  def update
    @publisher = find_publisher
    if @publisher.update(publisher_params)
      redirect_to @publisher, notice: 'Publisher updated.'
    else
      render :edit, status: :unprocessable_entity
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
    params.require(:publisher).permit(*Publisher.crud_attribute_names(action_name.to_sym, ability: self))
  end
end
