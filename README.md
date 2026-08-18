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
keeps systemd and `exedev`, opens the PVE console straight into `exedev` with
no key or password (autologin; the outer PVE/Raft login is the access
boundary), enables key-only sshd as an optional path when a key is injected,
disables root/password SSH, removes the VM `/dev/vda` mount, and creates unique
machine/SSH identity at first boot. PVE injects the optional public key; the
first-boot service moves it from root to `exedev` before sshd starts. With no
key, SSH login is simply disabled and the console still works.

CI builds this Dockerfile directly. On accepted `main`, it publishes immutable
commit coordinates plus `main` at `ghcr.io/bytemain/exeuntu-pve`; the existing
PVE bridge downloads and converts that OCI image. There is no separate
exporter, vztmpl builder, or Web terminal in this fork.
