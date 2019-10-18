FROM docker.io/ruby:2.5.5-alpine

RUN apk update && apk add --no-cache git build-base curl mariadb-dev

RUN bundle config --global frozen 1

COPY Gemfile Gemfile.lock /application/

# Change to the application's directory
WORKDIR /application

RUN bundle install --deployment --without development test

COPY . /application/

EXPOSE 80

ENTRYPOINT ["./entrypoint.sh"]
