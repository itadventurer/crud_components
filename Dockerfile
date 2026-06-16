# Live demo image for the bundled playground (test/dummy). NOT part of the gem
# (excluded from the gemspec). Runs the dummy in production on an ephemeral
# SQLite DB; DEMO_RESET reseeds it every 10 min so visitors can't damage
# anything persistently. (No libvips/poppler → PDF previews degrade to icons.)
FROM ruby:3.4-slim

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends build-essential libsqlite3-dev libyaml-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .
RUN bundle install

# Run rootless: a non-root user that owns the app and the writable dirs (an
# emptyDir volume can also be mounted over these for a read-only root fs).
RUN useradd --create-home --uid 1000 --shell /bin/bash app \
 && mkdir -p test/dummy/db test/dummy/storage test/dummy/tmp \
 && chown -R app:app /app
USER app

ENV RAILS_ENV=production \
    DEMO_RESET=1 \
    PORT=8080
EXPOSE 8080

# Fresh DB + schema + seed on boot (db:prepare seeds a newly created database),
# then serve. The DB is ephemeral, so every restart is a clean slate; the reset
# thread keeps a long-running one fresh.
CMD ["bash", "-lc", "cd test/dummy && bin/rails db:prepare && bin/rails server -b 0.0.0.0 -p ${PORT}"]
