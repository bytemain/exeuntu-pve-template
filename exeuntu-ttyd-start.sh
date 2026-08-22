#!/bin/sh
# Wrapper for ttyd that binds to the container's eth0 (vmbr1 private-bridge)
# address instead of loopback. The hub gateway reaches the web terminal over
# the private bridge; binding to eth0 (rather than 0.0.0.0) keeps ttyd off
# the tailnet interface so it is only reachable through the authenticated
# bridge proxy path.
set -eu

# Prefer eth0's first IPv4; fall back to the first address hostname reports.
addr=$(ip -4 -o addr show eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
if [ -z "$addr" ]; then
  addr=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -1 || true)
fi
if [ -z "$addr" ]; then
  echo "exeuntu-ttyd: no usable IPv4 address, falling back to loopback" >&2
  addr=127.0.0.1
fi

exec /usr/local/bin/ttyd -W -p 7681 -i "$addr" bash --login