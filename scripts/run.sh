#!/bin/bash
set -m
set -e

cp /usr/share/doc/tmux/examples/screen-keys.conf  /etc/tmux.conf
/etc/init.d/varnish start
tmux
