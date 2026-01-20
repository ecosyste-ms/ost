# ========================================================
# Builder stage
# ========================================================
FROM ruby:4.0.1-alpine AS builder

ENV APP_ROOT=/usr/src/app
ENV DATABASE_PORT=5432
WORKDIR $APP_ROOT

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    postgresql-dev \
    tzdata \
    curl-dev \
    yaml-dev

# Copy dependency files
COPY Gemfile Gemfile.lock .ruby-version $APP_ROOT/

# Install gems
RUN bundle config --global frozen 1 \
 && bundle config set without 'test' \
 && bundle install --jobs 2

# Copy application code
COPY . $APP_ROOT

# Precompile bootsnap cache
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# Precompile assets for production
RUN SECRET_KEY_BASE=1 RAILS_ENV=production bundle exec rake assets:precompile

# ========================================================
# Final stage
# ========================================================
FROM ruby:4.0.1-alpine

ENV APP_ROOT=/usr/src/app
ENV DATABASE_PORT=5432
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2
ENV RUBY_YJIT_ENABLE=1

WORKDIR $APP_ROOT

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    nodejs \
    postgresql-libs \
    tzdata \
    curl \
    yaml \
    jemalloc

# Copy installed gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy application code
COPY . $APP_ROOT

# Copy precompiled bootsnap cache from builder
COPY --from=builder $APP_ROOT/tmp/cache/bootsnap $APP_ROOT/tmp/cache/bootsnap

# Copy precompiled assets from builder
COPY --from=builder $APP_ROOT/public/assets $APP_ROOT/public/assets

# Create tmp directories for runtime
RUN mkdir -p tmp/pids tmp/cache tmp/sockets

# Startup
CMD ["bin/docker-start"]
