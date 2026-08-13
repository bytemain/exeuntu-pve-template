# exeuntu

exeuntu is available at http://ghcr.io/boldsoftware/exeuntu

exeuntu is the default base image for [exe.dev](https://exe.dev/). It is kitted-out
for developers, based on ubuntu24.04, and includes systemd.

We believe that minimal containers make for terrible developer (and agent)
experiences, so exeuntu includes a lot of stuff, mostly from apt.

You can build exeuntu with Docker, but running it, including systemd,
is difficult with Docker.

## PVE LXC target (bytemain fork)

This fork adds an explicit `pve` build target without changing the default
exeuntu OCI image. It produces a PVE-native, unprivileged LXC template with
normal systemd boot and key-only SSH as `exedev`; the provisioning bridge does
not embed a terminal.

```sh
sudo make build-pve-template
```

The build uses BuildKit's OCI exporter followed by `umoci`, not `docker
export`, so numeric ownership, xattrs and file capabilities survive. It emits a
normalized `vztmpl` tar.zst plus SHA-256 and provenance under `dist/`. The
archive is fully bound to the resulting OCI manifest/config and source commit;
the upstream Dockerfile still consumes rolling OS/tool inputs, so repeat builds
are not claimed byte-reproducible until those inputs are separately pinned.

PVE must inject one or more plain OpenSSH public keys at container creation.
Before sshd starts, a fail-closed first-boot unit validates them, moves them
from root to `exedev`, deletes the root copy, and creates per-container SSH host
keys. Root and password SSH remain disabled. No real key or credential is
stored in this public repository or template.

Installing an artifact on PVE and creating a successor container are separate
authorized steps. Diagnostic CT110 is not modified by this build.
