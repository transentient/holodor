#!/usr/bin/env bash
# publish-release.sh — create the GitHub Release for a published build in the PUBLIC repo and
# refresh the download landing page. Run AFTER publish-image.sh (image + .sha256 on the bucket)
# and after the release tag exists in the public repo (scripts/sync-public.sh pushes main; push
# the tag with `git -C ~/projects/holodor-public push origin release-<build>`).
#
# Usage:
#   scripts/publish-release.sh <build> [notes.md]
#     <build>    e.g. 20260927d  (tag release-<build>, image holodor-odin3-<build>-seedless.img.zst)
#     notes.md   release body; the download block is prepended automatically. Default:
#                docs/release-notes/<build>.md if present, else a minimal body.
#
# What the release carries: title "Holodor <build>", the download block (link, direct URL, sha256,
# INSTALL pointer), your notes, and the .sha256 file as its only asset (the image stays on the
# bucket; GitHub cannot host 3 GB). Re-running edits the existing release in place.
set -euo pipefail
source "$(dirname "$0")/lib.sh" 2>/dev/null || true
BUILD="${1:?usage: publish-release.sh <build> [notes.md]}"; NOTES="${2:-}"
REMOTE="${POCKNIX_IMAGE_RCLONE_REMOTE:-r2:holodor-images}"
BASE="${POCKNIX_IMAGE_URL:-https://holodor.bonesaw.com}"
GH_REPO="${HOLODOR_PUBLIC_REPO:-transentient/holodor}"
IMG="holodor-odin3-${BUILD}-seedless.img.zst"; TAG="release-${BUILD}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -n "${NOTES}" ] || { [ -f "${ROOT}/docs/release-notes/${BUILD}.md" ] && NOTES="${ROOT}/docs/release-notes/${BUILD}.md" || NOTES=""; }

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

The image is hosted outside GitHub because of its size. Follow **[INSTALL.md](https://github.com/${GH_REPO}/blob/main/INSTALL.md)** to write it to an SD card; it also covers the one-time bootloader step in Android.

EOF
  if [ -n "${NOTES}" ]; then cat "${NOTES}"; else printf '## Device\n\nAYN Odin 3 (Snapdragon 8 Elite).\n'; fi
} > "${tmp}/body.md"

if gh release view "${TAG}" -R "${GH_REPO}" >/dev/null 2>&1; then
  gh release edit "${TAG}" -R "${GH_REPO}" --title "Holodor ${BUILD}" --notes-file "${tmp}/body.md" >/dev/null
  gh release upload "${TAG}" -R "${GH_REPO}" --clobber "${tmp}/${IMG}.sha256" >/dev/null
  echo "updated release ${TAG}"
else
  gh release create "${TAG}" -R "${GH_REPO}" --title "Holodor ${BUILD}" --notes-file "${tmp}/body.md" "${tmp}/${IMG}.sha256" >/dev/null
  echo "created release ${TAG}"
fi
echo "https://github.com/${GH_REPO}/releases/tag/${TAG}"
"${ROOT}/scripts/publish-landing.sh"
