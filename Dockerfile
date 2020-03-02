FROM ruby:2.6.5-stretch

#RUN apt-get update && apt-get install sqlite3

#RUN apt-get update && apt-get install gcc sqlite-dev
#RUN wget -c "https://sqlite.org/contrib/download/extension-functions.c/download/extension-functions.c?get=25" -O extension-functions.c
#RUN gcc -fPIC -lm -shared extension-functions.c -o libsqlitefunctions.so

COPY . /application/

WORKDIR /application

RUN bundle install

EXPOSE 3000

ENTRYPOINT ["./entrypoint.sh"]