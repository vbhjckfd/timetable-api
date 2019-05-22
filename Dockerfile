FROM ruby:2.5

RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./
RUN bundle install --deployment --without development test

COPY . .

ENV RAILS_ENV production

ENTRYPOINT ['./entrypoint.sh']
