class DashboardController < ApplicationController
  def show
    @books = Book.all
    @reviews = Review.all
  end
end
