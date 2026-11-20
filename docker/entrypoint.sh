#!/bin/sh
# Starts the core. The data folder is the volume /var/lib/firefox-vpn.
# The first start opens the panel and the proxy to the network
# (firefox-vpn-core -setup-server) and prints the logins.
set -eu

data=/var/lib/firefox-vpn
mkdir -p "$data"
if [ ! -f "$data/config.json" ]; then
  firefox-vpn-core -data-dir "$data" -setup-server=-
fi
exec firefox-vpn-core -plain -data-dir "$data"
