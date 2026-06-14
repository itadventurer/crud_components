require 'zlib'
require 'stringio'

srand(42)

# A minimal solid-colour PNG encoder — avoids any image gem and any Active
# Storage inline/binary config (image/png serves inline by default, unlike SVG).
def solid_png(width, height, rgb)
  sig = [137, 80, 78, 71, 13, 10, 26, 10].pack('C*')
  chunk = lambda do |type, data|
    [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
  end
  ihdr = [width, height].pack('N2') + [8, 2, 0, 0, 0].pack('C*') # 8-bit RGB
  row = [0].pack('C') + (rgb.pack('C*') * width)                  # filter byte + pixels
  idat = Zlib::Deflate.deflate(row * height)
  sig + chunk.call('IHDR', ihdr) + chunk.call('IDAT', idat) + chunk.call('IEND', '')
end

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

# A couple of portrait "photos" per author — exercises has_many_attached
# end to end (derived image-list cell + multiple file field, zero gem config).
# Some authors are left without, so the empty "—" case shows too.
portrait_colors = %w[8d99ae cdb4db ffafcc a2d2ff bde0fe ffc8dd]
authors.each_with_index do |author, i|
  next if i.even?
  rand(1..2).times do |n|
    rgb = portrait_colors.sample.scan(/../).map { |h| h.to_i(16) }
    author.images.attach(io: StringIO.new(solid_png(160, 200, rgb)),
                         filename: "#{author.name.parameterize}-#{n}.png", content_type: 'image/png')
  end
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

  hex = cover_colors.sample.delete('#')
  rgb = [hex[0, 2], hex[2, 2], hex[4, 2]].map { |h| h.to_i(16) }
  book.cover.attach(io: StringIO.new(solid_png(120, 180, rgb)),
                    filename: "cover-#{i}.png", content_type: 'image/png')
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
