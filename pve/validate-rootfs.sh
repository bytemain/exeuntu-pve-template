#!/usr/bin/env bash
set -euo pipefail

rootfs=${1:?usage: validate-rootfs.sh ROOTFS}

fail() {
  printf 'validate-rootfs: %s\n' "$*" >&2
  exit 1
}

[[ -d "$rootfs" ]] || fail "not a directory: $rootfs"
[[ -f "$rootfs/etc/os-release" ]] || fail "missing /etc/os-release"
grep -qx 'VERSION_ID="24.04"' "$rootfs/etc/os-release" || fail "expected Ubuntu 24.04"

passwd_line=$(awk -F: '$1 == "exedev" { print; exit }' "$rootfs/etc/passwd")
[[ -n "$passwd_line" ]] || fail "missing exedev account"
IFS=: read -r _ _ uid gid _ home shell <<<"$passwd_line"
[[ "$uid" == 1000 && "$gid" == 1000 ]] || fail "exedev must remain uid/gid 1000"
[[ "$home" == /home/exedev && "$shell" == /bin/bash ]] || fail "unexpected exedev home or shell"
[[ -d "$rootfs/home/exedev" ]] || fail "missing exedev home"

[[ -x "$rootfs/usr/local/sbin/exeuntu-pve-firstboot" ]] || fail "first-boot helper is not executable"
[[ -L "$rootfs/etc/systemd/system/multi-user.target.wants/exeuntu-pve-firstboot.service" ]] || fail "first-boot unit is not enabled"
[[ -L "$rootfs/etc/systemd/system/multi-user.target.wants/ssh.service" ]] || fail "ssh.service is not enabled"
[[ ! -e "$rootfs/etc/systemd/system/ssh.service" ]] || fail "ssh.service remains masked"
[[ -L "$rootfs/etc/systemd/system/ssh.socket" && "$(readlink "$rootfs/etc/systemd/system/ssh.socket")" == /dev/null ]] || fail "ssh.socket must stay masked"

sshd_dropin=$rootfs/etc/ssh/sshd_config.d/60-exeuntu-pve.conf
grep -qx 'PermitRootLogin no' "$sshd_dropin" || fail "root SSH is not disabled"
grep -qx 'PasswordAuthentication no' "$sshd_dropin" || fail "password SSH is not disabled"
grep -qx 'AuthenticationMethods publickey' "$sshd_dropin" || fail "SSH is not key-only"
grep -qx 'AllowUsers exedev' "$sshd_dropin" || fail "SSH is not restricted to exedev"

[[ ! -s "$rootfs/etc/machine-id" ]] || fail "machine-id must be empty in the template"
[[ ! -e "$rootfs/var/lib/dbus/machine-id" ]] || fail "dbus machine-id must not be cloned"
[[ ! -e "$rootfs/var/lib/systemd/random-seed" ]] || fail "systemd random seed must not be cloned"
[[ ! -e "$rootfs/root/.ssh/authorized_keys" ]] || fail "root authorized_keys is baked into the template"
[[ ! -e "$rootfs/home/exedev/.ssh/authorized_keys" ]] || fail "exedev authorized_keys is baked into the template"

if find "$rootfs/etc/ssh" -maxdepth 1 -type f -name 'ssh_host_*_key' -print -quit | grep -q .; then
  fail "SSH host private key is baked into the template"
fi
if grep -Eq '^[[:space:]]*[^#].*[[:space:]]/[[:space:]]' "$rootfs/etc/fstab"; then
  fail "template fstab still mounts a root block device"
fi

printf 'rootfs validation PASS: Ubuntu 24.04, exedev uid 1000, key-only SSH bootstrap, clone identity clean\n'

