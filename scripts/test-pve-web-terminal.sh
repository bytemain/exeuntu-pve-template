#!/bin/sh
set -eu

root=${1:-.}

grep -Fq 'nginx /xterm/ -> xterm.js' "$root/README.md"
grep -Fq 'listen 443 ssl default_server;' "$root/nginx.conf"
grep -Fq 'location /xterm/' "$root/nginx.conf"
grep -Fq 'proxy_pass http://127.0.0.1:7681;' "$root/nginx.conf"
grep -Fq 'auth_basic_user_file /var/lib/exeuntu-pve/web-terminal/htpasswd;' "$root/nginx.conf"
grep -Fq -- '--interface 127.0.0.1' "$root/pve-web-terminal.sh"
grep -Fq -- '--base-path /xterm' "$root/pve-web-terminal.sh"
grep -Fq -- '--check-origin' "$root/pve-web-terminal.sh"
grep -Fq -- '--writable' "$root/pve-web-terminal.sh"
if grep -Fq -- '--credential' "$root/pve-web-terminal.sh"; then
  echo 'credential must not appear in the ttyd process command line' >&2
  exit 1
fi
grep -Fq 'NoNewPrivileges=yes' "$root/pve-web-terminal.service"
grep -Fq 'RestrictSUIDSGID=yes' "$root/pve-web-terminal.service"
grep -Fq 'Requires=exeuntu-pve-firstboot.service' "$root/pve-web-terminal-setup.service"
grep -Fq 'Before=nginx.service' "$root/pve-web-terminal.service"
grep -Fq 'Requires=exeuntu-web-terminal-setup.service' "$root/pve-nginx.service.conf"
grep -Fq 'WEB_TERMINAL_URL=https://%s/xterm/' "$root/pve-web-terminal-setup.sh"

# The pinned downloads must be immutable and checksum-verified.
grep -Eq '^ARG TTYD_VERSION=[0-9]' "$root/Dockerfile"
grep -Eq '^ARG TTYD_SHA256=[0-9a-f]{64}$' "$root/Dockerfile"
grep -Eq '^ARG EXE_SCROLL_VERSION=v[0-9]' "$root/Dockerfile"
grep -Eq '^ARG EXE_SCROLL_SHA256=[0-9a-f]{64}$' "$root/Dockerfile"
grep -Fq 'sha256sum -c -' "$root/Dockerfile"
