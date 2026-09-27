#!/usr/bin/env bash
# build-frontend.sh — build Decky's frontend ONCE on the build host and store it as
# decky-frontend-v<ver>.tar.zst next to this PKGBUILD (the same convention as Pocknix
# Control's committed dist/: no node/pnpm at package build time, the aarch64 chroot only
# runs python). Re-run when pkgver changes, then update sha256sums in the PKGBUILD.
#
# Inherited from upstream: frontend/package.json "build" = rollup -c, which writes
# backend/decky_loader/static/ (frontend/rollup.config.js). Invented here: the tarball.
# Source maps (~5 MB, chunk-*.js.map) are dropped: nothing on the device reads them.
#
# Usage: packages/decky-loader/build-frontend.sh [version]   (default: pkgver from PKGBUILD)
# Needs: node, pnpm (falls back to `npx -y pnpm@10`), git, tar, zstd, network.
# First built 2026-09-24 on fusor: node 26.7.0, pnpm 10.22.0 (pnpm-lock.yaml lockfileVersion 9).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ver=${1:-$(sed -n 's/^pkgver=//p' "$here/PKGBUILD")}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

git clone -q --depth 1 --branch "v$ver" https://github.com/SteamDeckHomebrew/decky-loader.git "$work/src"
pnpm=pnpm; command -v pnpm >/dev/null 2>&1 || pnpm="npx -y pnpm@10"
( cd "$work/src/frontend" && $pnpm install --frozen-lockfile && $pnpm build )

out="$here/decky-frontend-v$ver.tar.zst"
# Fixed order/owner/mtime so the same tag yields the same bytes (rollup's chunk names are
# content hashes; the lockfile pins the inputs).
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='2026-09-15 00:00:00 UTC' \
    --exclude='*.map' -C "$work/src/backend/decky_loader" -cf - static \
  | zstd -19 -q -f -o "$out"
sha256sum "$out"
