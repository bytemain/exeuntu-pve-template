# exeuntu

exeuntu is available at http://ghcr.io/boldsoftware/exeuntu

exeuntu is the default base image for [exe.dev](https://exe.dev/). It is kitted-out
for developers, based on ubuntu24.04, and includes systemd.

We believe that minimal containers make for terrible developer (and agent)
experiences, so exeuntu includes a lot of stuff, mostly from apt.

You can build exeuntu with Docker, but running it, including systemd,
is difficult with Docker.

## PVE fork

This fork modifies the same exeuntu image in place for normal PVE LXC use. It
keeps systemd and `exedev`, enables key-only sshd, disables root/password SSH,
removes the VM `/dev/vda` mount, and creates unique machine/SSH identity at
first boot. PVE injects the requested public key; the first-boot service moves
it from root to `exedev` before sshd starts.

CI builds this Dockerfile directly. On accepted `main`, it publishes immutable
commit coordinates plus `main` at `ghcr.io/bytemain/exeuntu-pve`; the existing
PVE bridge downloads and converts that OCI image. There is no separate
exporter or vztmpl builder.

## Browser terminal

Each created CT serves a normal landing page at `/` and a browser terminal at
`/xterm/` on the same HTTPS host:

```text
nginx /xterm/ -> xterm.js (ttyd on loopback) -> exe-scroll -> persistent exedev PTY
```

The first-boot unit creates a random Basic Auth password and a self-signed TLS
certificate for the CT's current `<ipv4-with-dashes>.sslip.io` hostname. The
terminal refuses to start until PVE key provisioning and terminal credential
generation have both completed. It runs as `exedev`, with `NoNewPrivileges`
and SUID/SGID blocked, so passwordless `sudo` is deliberately unavailable in
the browser terminal. Use SSH for administrative work.

After SSHing to the CT, print the exact URL and provisioned credential:

```sh
sudo exeuntu-web-terminal-info
```

`sslip.io` supplies DNS only. A private RFC1918 address is reachable only from
a network that can route to that address. The generated certificate is
self-signed, so the browser will show a warning; verify the hostname before
accepting it. A trusted certificate requires a separately authorized public
HTTP challenge, DNS control, or a Tailscale certificate/domain.
