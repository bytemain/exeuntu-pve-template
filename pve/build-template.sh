#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  printf 'build-template: %s\n' "$*" >&2
  exit 1
}

for command in docker skopeo umoci jq tar zstd sha256sum; do
  command -v "$command" >/dev/null || fail "missing required command: $command"
done
[[ $(id -u) -eq 0 ]] || fail "run as root to preserve ownership, xattrs, ACLs and capabilities"
[[ $(uname -s) == Linux ]] || fail "production template builds run on Linux"
[[ $(uname -m) == x86_64 ]] || fail "the current PVE target is x86-64"

source_commit=${SOURCE_COMMIT:-$(git -C "$repo_dir" rev-parse HEAD)}
source_date_epoch=${SOURCE_DATE_EPOCH:-$(git -C "$repo_dir" show -s --format=%ct "$source_commit")}
template_version=${TEMPLATE_VERSION:-$(date -u -d "@$source_date_epoch" +%Y.%m.%d)-${source_commit:0:12}}
build_dir=${BUILD_DIR:-$repo_dir/build/pve}
dist_dir=${DIST_DIR:-$repo_dir/dist}
oci_archive=$build_dir/exeuntu-pve.oci.tar
oci_dir=$build_dir/oci
bundle_dir=$build_dir/bundle
rootfs=$bundle_dir/rootfs
artifact=exeuntu-pve-${template_version}-amd64.tar.zst

rm -rf "$build_dir"
mkdir -p "$build_dir" "$dist_dir"

docker buildx build \
  --platform linux/amd64 \
  --target pve \
  --build-arg "EXEUNTU_GIT_VERSION=$source_commit" \
  --output "type=oci,dest=$oci_archive" \
  "$repo_dir"

skopeo copy "oci-archive:$oci_archive" "oci:$oci_dir:pve"
manifest_digest=$(jq -r '.manifests[0].digest' "$oci_dir/index.json")
config_digest=$(jq -r '.config.digest' "$oci_dir/blobs/sha256/${manifest_digest#sha256:}")
umoci unpack --image "$oci_dir:pve" "$bundle_dir"

"$repo_dir/pve/validate-rootfs.sh" "$rootfs"

rm -f "$dist_dir/$artifact" "$dist_dir/$artifact.sha256" "$dist_dir/$artifact.provenance.json"
tar \
  --create \
  --file=- \
  --directory="$rootfs" \
  --sort=name \
  --mtime="@$source_date_epoch" \
  --clamp-mtime \
  --numeric-owner \
  --acls \
  --xattrs \
  --xattrs-include='*' \
  --selinux \
  --format=posix \
  --pax-option=delete=atime,delete=ctime \
  . | zstd -19 --threads=1 --no-progress -o "$dist_dir/$artifact"

(
  cd "$dist_dir"
  sha256sum "$artifact" >"$artifact.sha256"
)
artifact_sha256=$(cut -d' ' -f1 "$dist_dir/$artifact.sha256")
artifact_bytes=$(stat -c '%s' "$dist_dir/$artifact")

jq -n \
  --arg schema_version '1' \
  --arg template_version "$template_version" \
  --arg artifact "$artifact" \
  --arg artifact_sha256 "$artifact_sha256" \
  --argjson artifact_bytes "$artifact_bytes" \
  --arg source_repository 'https://github.com/bytemain/exeuntu-pve-template' \
  --arg upstream_repository 'https://github.com/boldsoftware/exeuntu' \
  --arg source_commit "$source_commit" \
  --arg manifest_digest "$manifest_digest" \
  --arg config_digest "$config_digest" \
  --argjson source_date_epoch "$source_date_epoch" \
  --arg docker "$(docker buildx version)" \
  --arg skopeo "$(skopeo --version)" \
  --arg umoci "$(umoci --version)" \
  --arg tar "$(tar --version | head -1)" \
  --arg zstd "$(zstd --version | head -1)" \
  '{
    schemaVersion: $schema_version,
    templateVersion: $template_version,
    artifact: {name: $artifact, sha256: $artifact_sha256, bytes: $artifact_bytes},
    source: {repository: $source_repository, upstream: $upstream_repository, commit: $source_commit},
    buildImage: {manifestDigest: $manifest_digest, configDigest: $config_digest, os: "linux", architecture: "amd64"},
    reproducibility: {sourceDateEpoch: $source_date_epoch, tools: {docker: $docker, skopeo: $skopeo, umoci: $umoci, tar: $tar, zstd: $zstd}},
    runtimeContract: {
      loginUser: "exedev",
      keyInjection: "PVE ssh-public-keys -> first boot migration",
      rootSsh: false,
      passwordSsh: false,
      systemd: true,
      webTerminal: false
    }
  }' >"$dist_dir/$artifact.provenance.json"

printf 'Built %s\nSHA-256 %s\n' "$dist_dir/$artifact" "$artifact_sha256"

