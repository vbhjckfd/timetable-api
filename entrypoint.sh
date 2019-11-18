#!/bin/sh

#bundle exec rails server -p 80 -b 0.0.0.0
bundle exec puma -t 8:32 -w 3 --preload -b tcp://0.0.0.0:80
