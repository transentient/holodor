#!/usr/bin/env bash
# sync-public.sh — export the public source tree from this (private) dev repo.
#
# This repo is the source of truth and keeps everything (HANDOFF, plans, reviews,
# research). The public repo gets only what users need: `git archive HEAD` minus the
# paths marked export-ignore in .gitattributes. Each sync is one commit in the public
# clone, so the public history never contains the private material.
#
#   scripts/sync-public.sh [-m "message"] [--push]
#
# Public clone location: $HOLODOR_PUBLIC_DIR (default ~/projects/holodor-public).
# Edit README/INSTALL here, commit, then sync. Do not edit the public repo directly:
# the script refuses to run if the public clone is behind its origin.
set -euo pipefail
SRC=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DST=${HOLODOR_PUBLIC_DIR:-$HOME/projects/holodor-public}
MSG=""; PUSH=0
while [ $# -gt 0 ]; do
  case "$1" in
    -m) MSG=$2; shift 2 ;;
    --push) PUSH=1; shift ;;
    *) echo "usage: $0 [-m message] [--push]" >&2; exit 2 ;;
  esac
done
[ -n "$MSG" ] || MSG="sync from dev repo $(git -C "$SRC" rev-parse --short HEAD)"

if [ -n "$(git -C "$SRC" status --porcelain)" ]; then
  echo "warn: dev repo has uncommitted changes; exporting HEAD only" >&2
fi
if [ ! -d "$DST/.git" ]; then
  git init -q -b main "$DST"
fi
if git -C "$DST" remote get-url origin >/dev/null 2>&1; then
  git -C "$DST" fetch -q origin
  if git -C "$DST" rev-parse --verify -q origin/main >/dev/null \
     && ! git -C "$DST" merge-base --is-ancestor origin/main HEAD 2>/dev/null; then
    echo "error: $DST is behind origin/main (edited on GitHub?). Pull it, port those edits" >&2
    echo "       into the dev repo, then sync again." >&2
    exit 1
  fi
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git -C "$SRC" archive --format=tar HEAD | tar -x -C "$tmp"
rsync -a --delete --exclude=/.git "$tmp/" "$DST/"

git -C "$DST" add -A
if git -C "$DST" diff --cached --quiet; then
  echo "public tree unchanged, nothing to commit"
  exit 0
fi
git -C "$DST" commit -q -m "$MSG"
git -C "$DST" log -1 --stat --format='%h %s' | head -40 || true
if [ "$PUSH" = 1 ]; then
  git -C "$DST" push origin main
fi
