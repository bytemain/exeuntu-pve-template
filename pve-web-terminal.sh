#!/bin/sh
set -eu

[ "$(id -u)" -eq "$(id -u exedev)" ] || {
  echo "exeuntu-web-terminal: must run as exedev" >&2
  exit 1
}

exec /usr/local/bin/ttyd \
  --interface 127.0.0.1 \
  --port 7681 \
  --base-path /xterm \
  --check-origin \
  --writable \
  --max-clients 4 \
  --cwd /home/exedev \
  --terminal-type xterm-ghostty \
  --client-option "titleFixed=exeuntu terminal" \
  /usr/local/bin/exe-scroll \
  /home/exedev/.local/state/exe-scroll/browser.sock \
  -- /bin/bash -l
