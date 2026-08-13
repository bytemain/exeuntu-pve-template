#!/bin/sh
set -eu

umask 077
state_dir=/var/lib/exeuntu-pve/web-terminal
credential_file=$state_dir/credentials.env
htpasswd_file=$state_dir/htpasswd
endpoint_file=$state_dir/endpoint.env
cert_file=$state_dir/server.crt
key_file=$state_dir/server.key

fail() {
  echo "exeuntu-web-terminal-setup: $*" >&2
  exit 1
}

[ "$(id -u)" -eq 0 ] || fail "must run as root"
[ -f /var/lib/exeuntu-pve/firstboot-complete ] || fail "PVE identity setup is incomplete"
getent passwd exedev >/dev/null || fail "required exedev account is missing"

install -d -o root -g root -m 0755 "$state_dir"
install -d -o exedev -g exedev -m 0700 /home/exedev/.local/state/exe-scroll

if [ ! -s "$credential_file" ]; then
  password=$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')
  [ "${#password}" -eq 48 ] || fail "could not generate web terminal credential"
  printf 'WEB_TERMINAL_PASSWORD=%s\n' "$password" >"$credential_file"
fi
chown root:root "$credential_file"
chmod 0600 "$credential_file"

# Nginx owns HTTP Basic authentication. ttyd never receives the credential on
# its command line, so the password is not exposed through the process table.
# shellcheck disable=SC1090
. "$credential_file"
[ -n "${WEB_TERMINAL_PASSWORD:-}" ] || fail "web terminal credential is empty"
password_hash=$(openssl passwd -apr1 "$WEB_TERMINAL_PASSWORD")
printf 'exedev:%s\n' "$password_hash" >"$htpasswd_file"
chown root:www-data "$htpasswd_file"
chmod 0640 "$htpasswd_file"

# Prefer the address used by the default route. Fall back to the first global
# IPv4 address so isolated PVE networks without Internet egress still work.
ipv4=
attempt=0
while [ -z "$ipv4" ] && [ "$attempt" -lt 60 ]; do
  ipv4=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '
    { for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }
  ')
  if [ -z "$ipv4" ]; then
    ipv4=$(ip -4 -o address show scope global | awk 'NR == 1 { split($4, a, "/"); print a[1] }')
  fi
  [ -n "$ipv4" ] || sleep 1
  attempt=$((attempt + 1))
done
printf '%s\n' "$ipv4" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || fail "no global IPv4 address is ready"

sslip_host=$(printf '%s' "$ipv4" | tr . -).sslip.io
saved_host=
if [ -r "$endpoint_file" ]; then
  saved_host=$(sed -n 's/^WEB_TERMINAL_HOST=//p' "$endpoint_file" | head -n 1)
fi

if [ ! -s "$cert_file" ] || [ ! -s "$key_file" ] || [ "$saved_host" != "$sslip_host" ]; then
  tmp_dir=$(mktemp -d "$state_dir/.tls.XXXXXX")
  trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
  openssl req -x509 -newkey rsa:3072 -sha256 -nodes -days 365 \
    -subj "/CN=$sslip_host" \
    -addext "subjectAltName=DNS:$sslip_host,IP:$ipv4" \
    -keyout "$tmp_dir/server.key" -out "$tmp_dir/server.crt" >/dev/null 2>&1
  install -o root -g root -m 0600 "$tmp_dir/server.key" "$key_file"
  install -o root -g root -m 0644 "$tmp_dir/server.crt" "$cert_file"
  rm -rf "$tmp_dir"
  trap - EXIT HUP INT TERM
fi

printf 'WEB_TERMINAL_HOST=%s\nWEB_TERMINAL_URL=https://%s/xterm/\n' \
  "$sslip_host" "$sslip_host" >"$endpoint_file"
chown root:root "$endpoint_file"
chmod 0644 "$endpoint_file"
