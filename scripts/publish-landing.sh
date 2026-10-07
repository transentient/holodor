#!/usr/bin/env bash
# publish-landing.sh — generate the one-page download site and upload it as index.html to the
# image bucket (https://holodor.bonesaw.com/index.html). One button for the current release,
# the checksum, links to the device install guide, and an archive of earlier releases with their checksums.
#
# Source of truth for "what is a release": the dev repo's release-<build> tags (release-20260925,
# release-20260927d, ...). Images and .sha256 sidecars are read from the bucket, so a build that
# was tagged but never uploaded is skipped with a warning. Usage:
#   scripts/publish-landing.sh            # generate + upload
#   scripts/publish-landing.sh --dry-run  # generate to build/landing/index.html only
#
# The bucket's custom domain does not serve index documents at "/", so the page lives at
# /index.html; a Cloudflare redirect rule "/" -> "/index.html" (dashboard, one rule) makes the
# bare domain work. Nothing here overwrites a published image: only index.html is written.
set -euo pipefail
source "$(dirname "$0")/lib.sh" 2>/dev/null || true
REMOTE="${POCKNIX_IMAGE_RCLONE_REMOTE:-r2:holodor-images}"
BASE="${POCKNIX_IMAGE_URL:-https://holodor.bonesaw.com}"
REPO_URL="https://github.com/transentient/holodor"
OUT_DIR="$(dirname "$0")/../build/landing"; mkdir -p "${OUT_DIR}"; OUT="${OUT_DIR}/index.html"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

listing="$(rclone lsl "${REMOTE}" 2>/dev/null)" || { echo "rclone listing failed" >&2; exit 1; }
size_of() { awk -v f="$2" '$4==f{print $1}' <<<"$1"; }
human() { awk -v b="$1" 'BEGIN{printf "%.1f GB", b/1073741824}'; }   # GiB, printed the way README does

source "$(dirname "$0")/devices.sh"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INTRO_URL="${REPO_URL}#readme"

# One card per device: the latest published image (button) + the earlier ones (table).
cards=""
for dev in $(device_ids); do
  pretty="$(device_field "${dev}" pretty)"; blurb="$(device_field "${dev}" blurb)"
  install="$(device_field "${dev}" install)"; games="$(device_field "${dev}" games)"
  latest=""; rows=""
  for tag in $(device_tags "${dev}" "${ROOT}"); do
    build="$(tag_build "${tag}")"; img="holodor-${dev}-${build}-seedless.img.zst"
    sz="$(size_of "${listing}" "${img}")"
    if [ -z "${sz}" ]; then echo "warn: ${tag}: ${img} not in ${REMOTE}, skipping" >&2; continue; fi
    sha="$(rclone cat "${REMOTE}/${img}.sha256" 2>/dev/null | cut -d' ' -f1)"
    date="$(git -C "${ROOT}" log -1 --format=%cs "${tag}")"
    if [ -z "${latest}" ]; then
      latest="${build}"; latest_img="${img}"; latest_sz="${sz}"; latest_sha="${sha}"; latest_date="${date}"; latest_tag="${tag}"
    else
      rows="${rows}<tr><td>${build}</td><td>${date}</td><td><a href=\"${BASE}/${img}\">${img}</a> ($(human "${sz}"))</td><td><a href=\"${BASE}/${img}.sha256\">sha256</a> <code class=\"sha\">${sha}</code></td><td><a href=\"${REPO_URL}/releases/tag/${tag}\">notes</a></td></tr>"
    fi
  done
  if [ -z "${latest}" ]; then echo "warn: no published release for ${dev}; card skipped" >&2; continue; fi
  earlier=""
  [ -n "${rows}" ] && earlier="<details><summary>Earlier ${pretty} releases</summary><table><tr><th>Build</th><th>Date</th><th>Image</th><th>Checksum</th><th></th></tr>${rows}</table></details>"
  cards="${cards}
  <section class=\"card\">
    <h2>${pretty}</h2>
    <p class=\"blurb\">${blurb}</p>
    <a class=\"btn\" href=\"${BASE}/${latest_img}\">Download Holodor ${latest} for the ${pretty} · $(human "${latest_sz}")</a>
    <p class=\"meta\">Released ${latest_date}. SHA-256: <a href=\"${BASE}/${latest_img}.sha256\">checksum file</a> · <code class=\"sha\">${latest_sha}</code></p>
    <p class=\"links\"><a href=\"${INTRO_URL}\">What is Holodor</a> · <a href=\"${REPO_URL}/blob/main/${install}\">${pretty} install guide</a> · <a href=\"${REPO_URL}/blob/main/${games}\">Games tested on the ${pretty}</a> · <a href=\"${REPO_URL}/releases/tag/${latest_tag}\">Release notes</a></p>
    ${earlier}
  </section>"
done
[ -n "${cards}" ] || { echo "no release found in the bucket" >&2; exit 1; }

cat > "${OUT}" <<HTMLEOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Holodor downloads</title>
<meta name="description" content="Download Holodor, a SteamOS-like Linux for the AYN Odin 3 and the Retroid Pocket 5.">
<link rel="icon" type="image/png" href="${BASE}/holodor-icon.png">
<style>
  :root { --bg:#000000; --fg:#eaeaea; --muted:#a8a8a8; --accent:#7fb0ff; --card:#141414; --line:#2a2a2a; color-scheme: dark; }
  body { margin:0; background:var(--bg); color:var(--fg); font:16px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  main { max-width: 760px; margin: 0 auto; padding: 40px 16px 64px; }
  h1 { font-size: 2rem; margin: 0 0 4px; } h2 { margin: 0 0 4px; font-size: 1.4rem; } .sub { color: var(--muted); margin: 0 0 28px; }
  .logo { display:block; width: 320px; max-width: 60%; height: auto; image-rendering: pixelated; image-rendering: crisp-edges; margin: 0 auto 18px; }
  .visually-hidden { position:absolute; width:1px; height:1px; overflow:hidden; clip:rect(0 0 0 0); white-space:nowrap; }
  .card { background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 20px 20px 16px; margin-bottom: 24px; }
  .blurb { margin: 0 0 14px; }
  .btn { display:inline-block; background: var(--accent); color:#0b1a33; text-decoration:none; font-weight:600; padding: 14px 22px; border-radius: 10px; font-size: 1.05rem; }
  .btn:hover { filter: brightness(1.08); }
  .meta { color: var(--muted); margin: 12px 0 0; font-size: .95rem; word-break: break-all; }
  .links { margin: 10px 0 0; font-size: .95rem; }
  code.sha { font-size: .8rem; word-break: break-all; }
  details { margin-top: 12px; } summary { cursor: pointer; color: var(--muted); }
  table { width:100%; border-collapse: collapse; font-size: .92rem; } td, th { text-align:left; padding: 8px 6px; border-bottom: 1px solid var(--line); vertical-align: top; } th { color: var(--muted); font-weight: 600; }
  a { color: var(--accent); }
  footer { color: var(--muted); font-size: .9rem; margin-top: 32px; }
</style>
</head>
<body>
<main>
  <img class="logo" src="${BASE}/holodor-character.png" width="64" height="64" alt="Holodor">
  <h1 class="visually-hidden">Holodor</h1>
  <p class="sub">A SteamOS-like Linux for handhelds. Boots from an SD card next to Android. Pick your device:</p>
${cards}
  <footer>Source, issues and the install guides: <a href="${REPO_URL}">${REPO_URL}</a>. Generated $(date -u +%Y-%m-%d).</footer>
</main>
</body>
</html>
HTMLEOF
echo "generated ${OUT} ($(grep -c '<section class="card">' "${OUT}") device cards)"
if [ "${DRY}" = 0 ]; then
  rclone copyto "${OUT}" "${REMOTE}/index.html" --header-upload "Content-Type: text/html; charset=utf-8" && echo "uploaded -> ${BASE}/index.html"
fi
