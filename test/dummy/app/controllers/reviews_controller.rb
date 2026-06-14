class ReviewsController < ApplicationController
  def index = @reviews = Review.all

  def show
    @review = Review.find(params[:id])
  end

  def edit
    @review = Review.find(params[:id])
  end

  def update
    @review = Review.find(params[:id])
    if @review.update(review_params)
      redirect_to @review, notice: 'Review updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Review.find(params[:id]).destroy!
    redirect_to reviews_path, notice: 'Review deleted.'
  end

  private

  def review_params
    params.require(:review).permit(*Review.crud_attribute_names(action_name.to_sym, ability: self))
  end
end
