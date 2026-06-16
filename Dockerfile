# Live demo image for the bundled playground (test/dummy). NOT part of the gem
# (excluded from the gemspec). Runs the dummy app in development with an
# ephemeral SQLite DB that DEMO_RESET reseeds every 10 minutes.
FROM ruby:3.4-slim

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends build-essential libsqlite3-dev libyaml-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .
RUN bundle install

ENV RAILS_ENV=development \
    DEMO_RESET=1 \
    PORT=8080
EXPOSE 8080

# Fresh schema + seed on boot, then serve. The DB is ephemeral, so every
# restart is a clean slate; the reset thread keeps a long-running one fresh.
CMD ["bash", "-lc", "cd test/dummy && bin/rails db:schema:load db:seed && bin/rails server -b 0.0.0.0 -p ${PORT}"]
