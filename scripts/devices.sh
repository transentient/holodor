#!/usr/bin/env bash
# devices.sh — the public device table, sourced by the publish scripts and the landing page.
# One line per supported device: id (used in image names and tags), SoC, pretty name, install
# guide, games page, and the one-sentence blurb shown on the download page.
#   device_field <id> <field>   fields: soc pretty install games blurb
# Image names: holodor-<id>-<build>-seedless.img.zst. Tags: release-<id>-<build> (the Odin 3's
# early tags are release-<build>; device_tag_matches handles both).
device_ids() { echo "odin3 rp5"; }
device_field() {
  case "$1:$2" in
    odin3:soc)     echo sm8750 ;;
    odin3:pretty)  echo "AYN Odin 3" ;;
    odin3:install) echo "INSTALL-odin3.md" ;;
    odin3:games)   echo "docs/games-odin3.md" ;;
    odin3:blurb)   echo "Indie and AA games run well, and some AAA titles are playable." ;;
    rp5:soc)       echo sm8250 ;;
    rp5:pretty)    echo "Retroid Pocket 5" ;;
    rp5:install)   echo "INSTALL-rp5.md" ;;
    rp5:games)     echo "docs/games-rp5.md" ;;
    rp5:blurb)     echo "Best for 2D and lighter 3D games; heavy 3D titles run, but slowly." ;;
    *) return 1 ;;
  esac
}
# tags for a device, newest first: release-<id>-<build>, plus bare release-<build> for odin3
device_tags() {
  local id="$1" root="${2:-.}"
  { git -C "${root}" tag -l "release-${id}-*"
    [ "${id}" = odin3 ] && git -C "${root}" tag -l 'release-*' | grep -E '^release-[0-9]{8}[a-z]?$'; } | sort -r
}
tag_build() { echo "${1#release-}" | sed -E 's/^(odin3|rp5)-//'; }
