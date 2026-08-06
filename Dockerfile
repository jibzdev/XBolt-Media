FROM ruby:3.2.2

# System deps for native gems (pg, nokogiri, etc.)
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  build-essential \
  libpq-dev \
  dos2unix \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /myapp

ENV RAILS_ENV=production \
  RACK_ENV=production \
  BUNDLE_WITHOUT="development:test" \
  BUNDLE_DEPLOYMENT=1

# Install gems first (better layer caching)
COPY Gemfile Gemfile.lock /myapp/
RUN bundle install --jobs=4 --retry=3

# Copy app code
COPY . /myapp

# Precompile assets at build time. Use dummy secret so build doesn't need real secrets.
RUN SECRET_KEY_BASE=DUMMY bundle exec rails assets:precompile

COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 3001

# Run migrations on boot (optional via RUN_MIGRATIONS=1), then start puma
CMD ["bash", "-lc", "if [ \"${RUN_MIGRATIONS}\" = \"1\" ]; then bundle exec rails db:migrate; fi; bundle exec puma -C config/puma.rb"]
