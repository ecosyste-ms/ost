FROM ruby:3.4.6-slim

ENV APP_ROOT=/usr/src/app
ENV DATABASE_PORT=5432
WORKDIR $APP_ROOT

# * Setup system
# * Install Ruby dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    nodejs \
    libpq-dev \
    tzdata \
    curl \
    libcurl4-openssl-dev \
    libyaml-dev \
 && rm -rf /var/lib/apt/lists/*

# Will invalidate cache as soon as the Gemfile changes
COPY Gemfile Gemfile.lock .ruby-version $APP_ROOT/

RUN bundle config --global frozen 1 \
 && bundle config set without 'test' \
 && bundle install --jobs 2

# ========================================================
# Application layer

# Copy application code
COPY . $APP_ROOT

RUN bundle exec bootsnap precompile --gemfile app/ lib/

# Precompile assets for a production environment.
# This is done to include assets in production images on Dockerhub.
RUN SECRET_KEY_BASE=1 RAILS_ENV=production bundle exec rake assets:precompile

# Startup
CMD ["bin/docker-start"]