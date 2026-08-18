#!/bin/sh
set -eu

umask 077
source_keys=/root/.ssh/authorized_keys
target_dir=/home/exedev/.ssh
target_keys=$target_dir/authorized_keys
state_dir=/var/lib/exeuntu-pve

fail() {
  echo "exeuntu-pve-firstboot: $*" >&2
  exit 1
}

[ "$(id -u)" -eq 0 ] || fail "must run as root"
getent passwd exedev >/dev/null || fail "required exedev account is missing"

install -d -o root -g root -m 0755 "$state_dir"

if [ -f "$state_dir/firstboot-complete" ]; then
  # Already provisioned on a prior boot; this is an idempotent no-op.
  # ssh-keygen -A only fills keys that are missing, so it never rotates a
  # persistent host identity on restart.
  ssh-keygen -A >/dev/null
  [ -s "$target_keys" ] || echo "exeuntu-pve-firstboot: no exedev authorized_keys (SSH disabled; console still works)" >&2
  exit 0
fi

# First boot: generate fresh SSH host keys exactly once. The archive ships no
# host private keys.
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A >/dev/null

# SSH public key is OPTIONAL. The console autologs in to exedev with no key or
# password, protected by the outer surface (PVE login / Raft login). Without an
# injected key, SSH login simply stays disabled.
if [ ! -s "$source_keys" ]; then
  echo "exeuntu-pve-firstboot: no key injected; SSH disabled (console autologin to exedev is available)" >&2
  touch "$state_dir/firstboot-complete"
  exit 0
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT HUP INT TERM
sed -e 's/\r$//' -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$source_keys" >"$tmp"
[ -s "$tmp" ] || fail "the injected key file contains no public keys"

# Accept plain public keys only. authorized_keys options are deliberately
# rejected so template creation cannot smuggle commands or forwarding policy.
awk '
  $1 !~ /^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com)$/ { exit 1 }
' "$tmp" || fail "the injected file must contain plain OpenSSH public keys"

while IFS= read -r key; do
  printf '%s\n' "$key" | ssh-keygen -l -f - >/dev/null 2>&1 || fail "invalid OpenSSH public key"
done <"$tmp"

install -d -o exedev -g exedev -m 0700 "$target_dir"
install -o exedev -g exedev -m 0600 "$tmp" "$target_keys"
rm -f "$source_keys"

ssh-keygen -l -f "$target_keys" >"$state_dir/authorized-key-fingerprints"
chmod 0600 "$state_dir/authorized-key-fingerprints"
touch "$state_dir/firstboot-complete"
