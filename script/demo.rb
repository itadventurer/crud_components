#!/usr/bin/env ruby
# A guided tour of the query side against the seeded bookstore — run it with:
#   ruby script/demo.rb
# For the visual side, run the playground:
#   cd test/dummy && bin/rails db:schema:load db:seed && bin/rails server

ENV['RAILS_ENV'] = 'development'
require_relative '../test/dummy/config/environment'

if Book.count.zero?
  abort 'The playground database is empty — run: cd test/dummy && bin/rails db:schema:load db:seed'
end

def show(title, relation)
  puts "\n— #{title}"
  relation.limit(5).each { |r| puts "    #{CrudComponents::Structure.for(r.class).label_for(r)}" }
  puts "    (#{relation.count} total)"
end

puts "Bookstore: #{Book.count} books, #{Publisher.count} publishers, #{Review.count} reviews."

query = CrudComponents::Query.new(Book, { 'genre' => 'scifi', 'price_leq' => '25', 'sort' => 'title' },
                                  fieldset: :catalog)
show 'Scifi under 25 €, sorted by title (?genre=scifi&price_leq=25&sort=title)', query.apply(Book.all)

query = CrudComponents::Query.new(Book, { 'q' => Publisher.first.name }, fieldset: :catalog)
show "Global search for a publisher name (?q=#{Publisher.first.name}) — delegation through :publisher",
     query.apply(Book.all)

query = CrudComponents::Query.new(Review, { 'q' => Publisher.first.name })
show 'Reviews found via their book\'s publisher — two delegation hops', query.apply(Review.all)

query = CrudComponents::Query.new(Book, { 'sort' => 'title; DROP TABLE books' }, fieldset: :catalog)
puts "\n— Sort injection attempt produces no ORDER BY:"
puts "    #{query.apply(Book.all).to_sql[0, 120]}…"

puts "\nEverything above is driven by flat, shareable URL params — same engine the tables use."
