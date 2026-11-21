#!/bin/sh
# Starts the core. The data folder is the volume /var/lib/arman-vpn.
# The first start opens the panel and the proxy to the network
# (arman-vpn-core -setup-server) and prints the logins.
set -eu

data=/var/lib/arman-vpn
mkdir -p "$data"
if [ ! -f "$data/config.json" ]; then
  arman-vpn-core -data-dir "$data" -setup-server=-
fi
exec arman-vpn-core -plain -data-dir "$data"
