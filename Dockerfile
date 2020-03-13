FROM ruby:2.7-alpine

RUN apk add --no-cache build-base libxml2-dev libxslt-dev mariadb-dev git curl

COPY . /application/

WORKDIR /application

RUN bundle install

EXPOSE 3000

ENTRYPOINT ["./entrypoint.sh"]