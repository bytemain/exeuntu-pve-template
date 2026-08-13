#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

shellcheck \
  "$repo_dir/pve/build-template.sh" \
  "$repo_dir/pve/validate-rootfs.sh" \
  "$repo_dir/pve/exeuntu-pve-firstboot"

# Keys and credentials belong at PVE create time, never in this public fork.
if grep -RInE --exclude='test-source.sh' --exclude='README.md' --exclude-dir=.git \
  '(BEGIN (OPENSSH|RSA|EC) PRIVATE KEY|ssh-(ed25519|rsa) [A-Za-z0-9+/]{40,})' "$repo_dir/pve"; then
  printf 'credential or public-key material found in PVE source\n' >&2
  exit 1
fi

grep -q '^FROM exeuntu AS pve$' "$repo_dir/Dockerfile"
grep -q '^FROM exeuntu AS default$' "$repo_dir/Dockerfile"
printf 'PVE source validation PASS\n'

