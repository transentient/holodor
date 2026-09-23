#!/usr/bin/env bash
# publish-repo.sh — sign build/localrepo and publish it as the public [pocknix] repo.
#
# The localrepo IS already a complete pacman repo (packages + pocknix.db from repo-add,
# maintained by build-packages.sh); publishing is: stage the packages under GitHub-safe
# names, detach-sign every package, build a signed database over the staged names,
# export the public key alongside, and upload.
#
# HOLODOR BACKEND: GitHub Releases (one release TAG per SoC, e.g. tag "sm8750" in
# POCKNIX_REPO_GH_REPO). Shipped stanzas point at ${POCKNIX_REPO_URL}/${SOC}; with
# POCKNIX_REPO_URL=https://github.com/<owner>/<repo>/releases/download that join IS the
# tag's asset directory — no build-image.sh changes needed. GitHub asset names cannot
# contain ':' (epoch packages like gamescope-1:3.16...), so packages are staged into
# build/publish/<soc>/ with ':' -> '_' and the database is built THERE: the db FILENAME
# field then matches the asset name devices actually fetch. The localrepo keeps its
# canonical names (build-image's file:///localrepo mount depends on them).
# The upstream rclone backend is kept as a fallback (POCKNIX_REPO_RCLONE_REMOTE).
#
# Config (config/pocknix.conf or env):
#   POCKNIX_REPO_GPG_KEY        signing key id/email (required unless --unsigned)
#   POCKNIX_REPO_GH_REPO        owner/name of the GitHub repo hosting the releases
#                               (empty = skip GH upload)
#   POCKNIX_REPO_RCLONE_REMOTE  rclone destination (fallback backend; skipped if empty)
#
# Modes:
#   (default)    stage + sign + repo-add --sign + upload (GH first, else rclone)
#   --unsigned   skip signing (LAN-testing only — pair with SigLevel Optional TrustAll)
#   --no-upload  prepare the staging tree only (inspect before first publish)
#   --serve      after preparing, serve the staging tree over LAN http :8000
#                (foreground; point the device at http://<this-host>:8000/<soc>)
#
# Publish discipline (breaks OTA clients otherwise):
#   * NEVER republish the same package filename with different bytes — bump pkgrel.
#     Existing GH package assets are therefore skipped, not clobbered; only the
#     database files + pubkey are replaced each publish.
#   * Packages+sigs upload FIRST, database LAST, so a client never sees a db entry
#     whose package isn't uploaded yet.
#   * Space the calls out, no retry loops (the SourceForge lesson) — gh is invoked
#     serially and a failure aborts rather than retrying.

source "$(dirname "$0")/lib.sh"

# Per-SoC: each SoC's repo is a self-contained tree published under its own GH tag /
# <rclone-remote>/<soc> (tuned packages share pkgnames across SoCs with different
# binaries). Run once per SoC: `make publish DEVICE=<target of that soc>`.
LOCALREPO="${LOCALREPO_DIR}"
STAGING="${BUILD_DIR}/publish/${SOC}"
REPO_DB="pocknix.db.tar.gz"
GH_REPO="${POCKNIX_REPO_GH_REPO:-}"
RCLONE_DEST="${POCKNIX_REPO_RCLONE_REMOTE:+${POCKNIX_REPO_RCLONE_REMOTE}/${SOC}}"
unsigned=0 serve=0 upload=1
for a in "$@"; do
  case "$a" in
    --unsigned)  unsigned=1 ;;
    --no-upload) upload=0 ;;
    --serve)     serve=1 ;;
    *) die "unknown arg: $a (known: --unsigned --no-upload --serve)" ;;
  esac
done

[ -d "${LOCALREPO}" ] || die "no ${LOCALREPO} — run 'make packages' first"
shopt -s nullglob

# --- stage packages under GitHub-safe names (':' -> '_') -----------------------------
mkdir -p "${STAGING}"
declare -A want=()   # staged basename -> 1 (packages + their sigs live here)
staged=()            # staged package paths, for repo-add
for p in "${LOCALREPO}"/*.pkg.tar.*; do
  [[ "$p" == *.sig ]] && continue
  base="$(basename "$p")"
  safe="${base//:/_}"
  want["$safe"]=1
  dst="${STAGING}/${safe}"
  # hardlink (same fs, root-owned source is fine); refresh if the source changed
  if [ ! "${dst}" -ef "${p}" ]; then
    rm -f "${dst}" "${dst}.sig"
    ln "${p}" "${dst}" 2>/dev/null || cp "${p}" "${dst}"
  fi
  staged+=("${dst}")
done
[ "${#staged[@]}" -gt 0 ] || die "no packages in ${LOCALREPO}"
# prune staged packages whose source vanished from the localrepo (keeps GH prune honest)
for f in "${STAGING}"/*.pkg.tar.*; do
  [[ "$f" == *.sig ]] && continue
  [ -n "${want[$(basename "$f")]:-}" ] || { log "pruning stale $(basename "$f")"; rm -f "$f" "$f.sig"; }
done
log "staged ${#staged[@]} packages in ${STAGING}"

# --- sign + build the database over the staged names ---------------------------------
if [ "${unsigned}" -eq 0 ]; then
  [ -n "${POCKNIX_REPO_GPG_KEY}" ] || die "POCKNIX_REPO_GPG_KEY unset (or pass --unsigned for LAN testing)
  one-time key setup: gpg --quick-gen-key 'Holodor Packaging <noreply-addr>' ed25519 sign 2y"
  need_tool gpg
  log "signing packages with ${POCKNIX_REPO_GPG_KEY} (only missing/stale sigs)"
  for p in "${staged[@]}"; do
    # re-sign only when missing or older than the package: gpg signatures are
    # nondeterministic (timestamped), and stable bytes = stable client caches
    if [ ! -f "${p}.sig" ] || [ "${p}" -nt "${p}.sig" ]; then
      gpg --detach-sign --no-armor --yes -u "${POCKNIX_REPO_GPG_KEY}" "${p}" \
        || die "gpg sign failed for ${p}"
    fi
  done
  log "rebuilding signed repo database"
  ( cd "${STAGING}" && repo-add --sign --key "${POCKNIX_REPO_GPG_KEY}" -q "${REPO_DB}" "${staged[@]}" ) \
    || die "repo-add --sign failed (is repo-add installed?)"
  # export the public key next to the repo so devices can fetch + lsign it
  gpg --export --armor "${POCKNIX_REPO_GPG_KEY}" > "${STAGING}/pocknix-repo.gpg"
  ok "signed: ${#staged[@]} packages + ${REPO_DB} + pocknix-repo.gpg"
else
  warn "publishing UNSIGNED (LAN testing only — device stanza needs SigLevel = Optional TrustAll)"
  ( cd "${STAGING}" && repo-add -q "${REPO_DB}" "${staged[@]}" ) || die "repo-add failed"
fi

# --- upload ---------------------------------------------------------------------------
# db/files are symlinks from repo-add; the uploaded/served artifact must be the content
# under the SYMLINK'S name (pocknix.db is what pacman fetches).
db_files=("${STAGING}/pocknix.db" "${STAGING}/pocknix.files")
[ "${unsigned}" -eq 0 ] && db_files+=("${STAGING}/pocknix.db.sig" "${STAGING}/pocknix.files.sig" "${STAGING}/pocknix-repo.gpg")

if [ "${upload}" -eq 0 ]; then
  warn "--no-upload: staging tree ready in ${STAGING}, nothing uploaded"
elif [ -n "${GH_REPO}" ]; then
  need_tool gh
  gh release view "${SOC}" -R "${GH_REPO}" >/dev/null 2>&1 \
    || die "release tag '${SOC}' not found in ${GH_REPO} — create it once:
  gh release create ${SOC} -R ${GH_REPO} --title 'Holodor pacman repo (${SOC})' \\
    --notes 'pacman OTA channel — fetched by pacman, not for manual download' --latest=false"
  mapfile -t remote < <(gh release view "${SOC}" -R "${GH_REPO}" --json assets -q '.assets[].name')
  have() { local n; for n in "${remote[@]}"; do [ "$n" = "$1" ] && return 0; done; return 1; }
  # 1) packages + sigs first; existing package assets are SKIPPED (same-name = same
  #    bytes by discipline; a changed package must be a new pkgrel/filename)
  up=0
  for f in "${STAGING}"/*.pkg.tar.*; do
    have "$(basename "$f")" && continue
    log "uploading $(basename "$f")"
    gh release upload "${SOC}" "$f" -R "${GH_REPO}" || die "upload failed: $f"
    up=$((up+1))
  done
  # 2) prune remote package assets that no longer exist locally
  for n in "${remote[@]}"; do
    case "$n" in
      pocknix.db*|pocknix.files*|pocknix-repo.gpg) continue ;;
    esac
    if [ ! -e "${STAGING}/${n}" ]; then
      log "deleting remote stale ${n}"
      gh release delete-asset "${SOC}" "${n}" -R "${GH_REPO}" -y || die "delete failed: ${n}"
    fi
  done
  # 3) database + key LAST, clobbered (these are the only same-name replacements)
  gh release upload "${SOC}" "${db_files[@]}" -R "${GH_REPO}" --clobber || die "db upload failed"
  ok "published to github.com/${GH_REPO} tag ${SOC} (${up} new packages)"
elif [ -n "${RCLONE_DEST}" ]; then
  need_tool rclone
  log "syncing -> ${RCLONE_DEST}"
  rclone copy --include '*.pkg.tar.*' --exclude '*.old*' "${STAGING}" "${RCLONE_DEST}"
  rclone copy -L --include 'pocknix.db*' --include 'pocknix.files*' --include 'pocknix-repo.gpg' \
    --exclude '*.old*' "${STAGING}" "${RCLONE_DEST}"
  rclone sync -L --exclude '*.old*' "${STAGING}" "${RCLONE_DEST}"
  ok "published to ${RCLONE_DEST}"
else
  warn "no backend configured (POCKNIX_REPO_GH_REPO / POCKNIX_REPO_RCLONE_REMOTE) — nothing uploaded"
fi

if [ "${serve}" -eq 1 ]; then
  need_tool python3
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  # serve the PARENT dir: shipped stanzas point at <base>/<soc>, so the URL path
  # must include the SoC segment (build the test image with POCKNIX_REPO_URL=http://<host>:8000)
  log "serving ${BUILD_DIR}/publish on http://${ip:-<this-host>}:8000 (Ctrl-C to stop)"
  log "device stanza:  [pocknix]  Server = http://${ip:-<host>}:8000/${SOC}"
  python3 -m http.server 8000 -d "${BUILD_DIR}/publish"
fi
