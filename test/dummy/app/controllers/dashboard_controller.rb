# frozen_string_literal: true

class DashboardController < ApplicationController
  def show
    @books = Book.all
    @reviews = Review.all
  end
end
