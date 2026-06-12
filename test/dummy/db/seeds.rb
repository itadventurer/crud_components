srand(42)

puts 'Seeding the bookstore…'

[Review, Book, Author, Publisher].each(&:delete_all)
ActiveRecord::Base.connection.execute('DELETE FROM authors_books')

publishers = [
  ['Tor Books', 1980], ['Ace', 1952], ['Orbit', 1974], ['Gollancz', 1927],
  ['DAW', 1971], ['Baen', 1983], ['Del Rey', 1977], ['Vintage', 1954]
].map do |name, year|
  Publisher.create!(name: name, slug: name.parameterize, founded_on: Date.new(year, 1, 1))
end

first_names = %w[Ursula Joe Ann Frank Iain Octavia Stanisław Margaret Kim Ted Liu Becky Martha Adrian Mary]
last_names = %w[Le\ Guin Abercrombie Leckie Herbert Banks Butler Lem Atwood Robinson Chiang Cixin Chambers Wells Tchaikovsky Shelley]

authors = first_names.zip(last_names).map do |first, last|
  Author.create!(name: "#{first} #{last}", email: "#{first.parameterize}@example.com")
end

nouns = %w[Dune Forest Empire Station Engine Garden Mirror Tower City Ocean Signal Archive Winter Machine Door]
adjectives = %w[Dispossessed Silent Endless Burning Hidden Ancient Quiet Broken Distant Luminous]
genres = Book.genres.keys

cover_colors = %w[#264653 #2a9d8f #e9c46a #f4a261 #e76f51 #6d597a #355070 #b56576]

120.times do |i|
  title = "The #{adjectives.sample} #{nouns.sample} #{i + 1}"
  book = Book.create!(
    title: title,
    subtitle: [nil, "A novel of the #{nouns.sample}"].sample,
    slug: title.parameterize,
    blurb: "#{title} — #{adjectives.sample.downcase} tales of the #{nouns.sample.downcase}.\n\nA story in #{rand(2..5)} parts.",
    price: (rand(500..4500) / 100.0).round(2),
    purchase_price: (rand(100..2000) / 100.0).round(2),
    pages: rand(120..900),
    published_on: Date.new(rand(1950..2025), rand(1..12), rand(1..28)),
    active: rand > 0.2,
    genre: genres.sample,
    metadata: { isbn: "978-#{rand(10**9)}", binding: %w[hardcover paperback].sample },
    publisher: [*publishers, nil].sample,
    authors: authors.sample(rand(1..3))
  )

  color = cover_colors.sample
  svg = <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" width="120" height="180">
      <rect width="120" height="180" fill="#{color}"/>
      <text x="60" y="95" font-family="Georgia" font-size="48" fill="white" text-anchor="middle">#{title[4]}</text>
    </svg>
  SVG
  book.cover.attach(io: StringIO.new(svg), filename: "cover-#{i}.svg", content_type: 'image/svg+xml')
end

reviewers = %w[Ada Linus Grace Alan Edsger Barbara Donald Radia]
phrases = ['Could not put it down.', 'A classic in the making.', 'Slow start, great finish.',
           'The world-building is superb.', 'Not my cup of tea.', 'Read it twice already.']

Book.find_each do |book|
  rand(0..4).times do
    Review.create!(book: book, rating: rand(1..5), reviewer_name: reviewers.sample,
                   body: phrases.sample(rand(1..2)).join(' '))
  end
end

puts "  #{Publisher.count} publishers, #{Author.count} authors, #{Book.count} books, #{Review.count} reviews."
