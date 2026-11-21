#!/usr/bin/env bash
# Builds the Linux core into dist/: arman-vpn-core-linux-amd64.tar.gz,
# arman-vpn-core-linux-arm64.tar.gz, and arman-vpn-core-linux-armv7.tar.gz
# (32-bit ARM routers; docs/OPENWRT.md), each an arman-vpn-core-linux-<arch>
# folder with the core, core/scripts/install-systemd.sh, and the license;
# install.sh (at the repository root) installs one. The version is
# "major.minor.patch" from app/pubspec.yaml.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(sed -n 's/^version:[[:space:]]*\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' "$root/app/pubspec.yaml")"
[ -n "$version" ] || { echo "no version in app/pubspec.yaml" >&2; exit 1; }

goflags="-s -w -X github.com/armanlife/arman-vpn-client/core/internal/version.Current=$version"

# Optional local build settings (scripts/build-local.sh), for a machine or a
# runner put together with its own build profile; absent, as in a plain
# checkout, this builds the ordinary public client. It sets local_tags and
# local_ldflags, which the build below uses.
local_tags=''
local_ldflags=''
if [ -f "$root/scripts/build-local.sh" ]; then
  # shellcheck source=/dev/null
  . "$root/scripts/build-local.sh"
fi
core_goflags="$goflags$local_ldflags"
# Used unquoted below on purpose: tags are comma-separated and never contain
# spaces, so this is one argument pair or nothing at all.
core_tags=''
[ -z "$local_tags" ] || core_tags="-tags $local_tags"

mkdir -p "$root/dist"
for arch in amd64 arm64 armv7; do
  name="arman-vpn-core-linux-$arch"
  stage="$(mktemp -d)"
  mkdir "$stage/$name"
  (cd "$root/core" && CGO_ENABLED=0 GOOS=linux GOARCH="${arch/armv7/arm}" GOARM=7 go build -trimpath \
    $core_tags -ldflags "$core_goflags" \
    -o "$stage/$name/arman-vpn-core" ./cmd/arman-vpn-core)
  install -m 0755 "$root/core/scripts/install-systemd.sh" "$stage/$name/install-systemd.sh"
  install -m 0644 "$root/LICENSE" "$stage/$name/LICENSE"
  tar -czf "$root/dist/$name.tar.gz" -C "$stage" --owner=0 --group=0 "$name"
  rm -rf "$stage"
  echo "Built dist/$name.tar.gz ($version)"
done
