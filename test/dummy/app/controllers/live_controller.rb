class LiveController < ApplicationController
  def index
    @reviews = Review.order(created_at: :desc).limit(8)
  end

  # Simulate an external change. Returns 204 so Turbo stays on the page; the
  # morph-refresh poll picks up the new row within a couple of seconds.
  def poke
    book = Book.order('RANDOM()').first
    book.reviews.create!(rating: rand(1..5), reviewer_name: %w[Ada Linus Grace Alan].sample,
                         body: 'Just added — watch it morph in.')
    head :no_content
  end
end
