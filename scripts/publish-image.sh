#!/usr/bin/env bash
# publish-image.sh — compress, checksum, and upload the SD image for public download.
#
# The pacman repo ships updates (publish-repo.sh); the image is only for first
# installs, so publishing one is: zstd-compress it under a DATE-STAMPED name,
# write a sha256, and rclone the pair to the public bucket. Date-stamped because
# a public filename must never change bytes (CDN caches would mix chunks of two
# different disk images — a corrupted flash for the downloader).
#
# Config (config/pocknix.conf or env):
#   POCKNIX_IMAGE_RCLONE_REMOTE  rclone destination, e.g. r2:pocknix/images
#                                (optional: skip upload if empty)
#   POCKNIX_IMAGE_URL            public base URL for that destination, only used
#                                to print the final download link
#
# NB: build/ is root-owned after sudo builds; run with sudo -E if the compressed
# output can't be written next to the image.

source "$(dirname "$0")/lib.sh"

IMG="${IMAGE_DIR}/pocknix-${SOC}-sd.img"
STAMP="$(date +%Y%m%d)"
# HOLODOR: release candidates are compressed by the respin recipe under the public
# name holodor-odin3-<date>-seedless.img.zst (+ .sha256). Pass that file as
# POCKNIX_IMAGE_FILE to upload it as-is (no recompression, same bytes the card was
# verified against). Without it, the harness default below applies.
if [ -n "${POCKNIX_IMAGE_FILE:-}" ]; then
  OUT="${POCKNIX_IMAGE_FILE}"
  [ -f "${OUT}" ] || die "POCKNIX_IMAGE_FILE=${OUT} does not exist"
  [ -f "${OUT}.sha256" ] || die "${OUT}.sha256 missing — the respin writes it next to the image"
  IMG="${OUT}"   # skip the compression branch below
else
  OUT="${IMAGE_DIR}/pocknix-${SOC}-${STAMP}-sd.img.zst"
  [ -f "${IMG}" ] || die "no ${IMG} — run 'make sd-image' first"
fi
need_tool zstd
need_tool sha256sum

if [ -n "${POCKNIX_IMAGE_FILE:-}" ]; then
  log "publishing prebuilt $(basename "${OUT}") ($(du -h "${OUT}" | cut -f1))"
elif [ ! -f "${OUT}" ] || [ "${IMG}" -nt "${OUT}" ]; then
  log "compressing $(du -h "${IMG}" | cut -f1) image -> $(basename "${OUT}") (zstd -12, all cores)"
  zstd -T0 -12 --force "${IMG}" -o "${OUT}" || die "zstd failed (root-owned ${IMAGE_DIR}? use sudo -E)"
else
  log "$(basename "${OUT}") is up to date — skipping compression"
fi

if [ -z "${POCKNIX_IMAGE_FILE:-}" ]; then
  log "writing sha256"
  ( cd "${IMAGE_DIR}" && sha256sum "$(basename "${OUT}")" > "${OUT}.sha256" )
fi
( cd "$(dirname "${OUT}")" && sha256sum -c "$(basename "${OUT}").sha256" >/dev/null ) || die "sha256 sidecar does not match ${OUT}"
ok "prepared: $(basename "${OUT}") ($(du -h "${OUT}" | cut -f1)) + .sha256"

if [ -n "${POCKNIX_IMAGE_RCLONE_REMOTE}" ]; then
  need_tool rclone
  log "uploading -> ${POCKNIX_IMAGE_RCLONE_REMOTE}"
  # image first, checksum last: a visible .sha256 implies the image is complete
  rclone copy --progress "${OUT}" "${POCKNIX_IMAGE_RCLONE_REMOTE}/"
  rclone copy "${OUT}.sha256" "${POCKNIX_IMAGE_RCLONE_REMOTE}/"
  ok "uploaded"
  if [ -n "${POCKNIX_IMAGE_URL}" ]; then
    log "download link: ${POCKNIX_IMAGE_URL}/$(basename "${OUT}")"
  fi
else
  warn "POCKNIX_IMAGE_RCLONE_REMOTE unset — nothing uploaded (artifacts left in ${IMAGE_DIR})"
fi
