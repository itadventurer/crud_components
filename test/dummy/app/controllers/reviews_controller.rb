class ReviewsController < ApplicationController
  def index; end

  def show
    @review = Review.find(params[:id])
  end

  def edit
    @review = Review.find(params[:id])
  end

  def destroy
    Review.find(params[:id]).destroy!
    redirect_to reviews_path, notice: 'Review deleted.'
  end
end
