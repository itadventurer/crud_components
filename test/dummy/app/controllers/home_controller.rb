class HomeController < ApplicationController
  # The playground's landing page: a living index of every feature, each card
  # linking to the demo that shows it working. A sample record gives the
  # detail/form cards a real deep link.
  def index
    @sample_book = Book.order(:id).first
  end
end
