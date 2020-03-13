#!/bin/sh

RUBYOPT='-W:no-deprecated' bundle exec rails server -b 0.0.0.0
#bundle exec puma -t 8:32 -w 3 --preload -b tcp://0.0.0.0
