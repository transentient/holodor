#!/usr/bin/env bash
# publish-release.sh — create the GitHub Release for a published build in the PUBLIC repo and
# refresh the download landing page. Run AFTER publish-image.sh (image + .sha256 on the bucket)
# and after the release tag exists in the public repo (scripts/sync-public.sh pushes main; push
# the tag with `git -C ~/projects/holodor-public push origin release-<build>`).
#
# Usage:
#   scripts/publish-release.sh <device> <build> [notes.md]
#     <device>   odin3 | rp5 (scripts/devices.sh)
#     <build>    e.g. 20260927d  (tag release-<device>-<build>, or release-<build> for the Odin 3's
#                early releases; image holodor-<device>-<build>-seedless.img.zst)
#     notes.md   release body; the download block is prepended automatically. Default:
#                docs/release-notes/<build>.md if present, else a minimal body.
#
# What the release carries: title "Holodor <build>", the download block (link, direct URL, sha256,
# INSTALL pointer), your notes, and the .sha256 file as its only asset (the image stays on the
# bucket; GitHub cannot host 3 GB). Re-running edits the existing release in place.
set -euo pipefail
source "$(dirname "$0")/lib.sh" 2>/dev/null || true
source "$(dirname "$0")/devices.sh"
DEVICE="${1:?usage: publish-release.sh <device> <build> [notes.md]}"; BUILD="${2:?usage: publish-release.sh <device> <build> [notes.md]}"; NOTES="${3:-}"
PRETTY="$(device_field "${DEVICE}" pretty)" || { echo "unknown device ${DEVICE}" >&2; exit 1; }
INSTALL_DOC="$(device_field "${DEVICE}" install)"
REMOTE="${POCKNIX_IMAGE_RCLONE_REMOTE:-r2:holodor-images}"
BASE="${POCKNIX_IMAGE_URL:-https://holodor.bonesaw.com}"
GH_REPO="${HOLODOR_PUBLIC_REPO:-transentient/holodor}"
IMG="holodor-${DEVICE}-${BUILD}-seedless.img.zst"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# tag: release-<device>-<build>; the Odin 3's pre-10-07 releases are tagged release-<build>
TAG="release-${DEVICE}-${BUILD}"
if [ "${DEVICE}" = odin3 ] && git -C "${ROOT}" tag -l "release-${BUILD}" | grep -q .; then TAG="release-${BUILD}"; fi
[ -n "${NOTES}" ] || { for n in "${ROOT}/docs/release-notes/${DEVICE}-${BUILD}.md" "${ROOT}/docs/release-notes/${BUILD}.md"; do [ -f "${n}" ] && { NOTES="${n}"; break; }; done; }

tmp="$(mktemp -d)"; trap 'rm -rf "${tmp}"' EXIT
rclone copyto "${REMOTE}/${IMG}.sha256" "${tmp}/${IMG}.sha256" || { echo "no ${IMG}.sha256 on ${REMOTE} — run publish-image.sh first" >&2; exit 1; }
SHA="$(cut -d' ' -f1 "${tmp}/${IMG}.sha256")"
SIZE="$(rclone lsl "${REMOTE}" | awk -v f="${IMG}" '$4==f{print $1}')"; [ -n "${SIZE}" ] || { echo "${IMG} not on ${REMOTE}" >&2; exit 1; }
GB="$(awk -v b="${SIZE}" 'BEGIN{printf "%.1f", b/1073741824}')"
gh api "repos/${GH_REPO}/git/ref/tags/${TAG}" >/dev/null 2>&1 || { echo "tag ${TAG} is not in ${GH_REPO} — push it first" >&2; exit 1; }

{
  cat <<EOF
## Download

**[${IMG}](${BASE}/${IMG})** (${GB} GB) · [SHA-256 checksum](${BASE}/${IMG}.sha256) (also attached below)

Direct URL: ${BASE}/${IMG}

SHA-256: \`${SHA}\`

This image is for the **${PRETTY}** only. It is hosted outside GitHub because of its size. Follow **[${INSTALL_DOC}](https://github.com/${GH_REPO}/blob/main/${INSTALL_DOC})** to write it to an SD card; it also covers the one-time bootloader step in Android.

EOF
  if [ -n "${NOTES}" ]; then cat "${NOTES}"; else printf '## Device\n\n%s.\n' "${PRETTY}"; fi
} > "${tmp}/body.md"

if gh release view "${TAG}" -R "${GH_REPO}" >/dev/null 2>&1; then
  gh release edit "${TAG}" -R "${GH_REPO}" --title "Holodor ${PRETTY} ${BUILD}" --notes-file "${tmp}/body.md" >/dev/null
  gh release upload "${TAG}" -R "${GH_REPO}" --clobber "${tmp}/${IMG}.sha256" >/dev/null
  echo "updated release ${TAG}"
else
  gh release create "${TAG}" -R "${GH_REPO}" --title "Holodor ${PRETTY} ${BUILD}" --notes-file "${tmp}/body.md" "${tmp}/${IMG}.sha256" >/dev/null
  echo "created release ${TAG}"
fi
echo "https://github.com/${GH_REPO}/releases/tag/${TAG}"
"${ROOT}/scripts/publish-landing.sh"
