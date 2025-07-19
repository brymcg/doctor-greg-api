FROM ruby:3.2-slim

# Install dependencies
RUN apt-get update -qq && apt-get install -yq --no-install-recommends \
    build-essential \
    gnupg2 \
    curl \
    less \
    git \
    libpq-dev \
    postgresql-client \
    libyaml-dev \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set working directory
WORKDIR /app

# Copy Gemfile
COPY Gemfile* ./

# Install gems
RUN bundle install

# Copy application code
COPY . .

# Create tmp/pids directory
RUN mkdir -p tmp/pids

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"] 