#!/usr/bin/env bash
# build-openabl.sh — build Holodor ABL (OpenABL v1.1 with Holodor wordmark,
# devinfo settings sync, and single-DTB auto-selection) for SM8250, SM8550,
# and SM8750, and copy the signed ELF binaries into our bootloader packages.
#
# Usage:
#   ./scripts/build-openabl.sh [sm8250 sm8550 sm8750]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPENABL_DIR="${OPENABL_DIR:-${REPO_ROOT}/build/competitors/OpenABL}"
OPENABL_URL="https://github.com/OpenHandheldCollective/OpenABL.git"
OPENABL_TAG="v1.1"
PATCH_FILE="${REPO_ROOT}/scripts/holodor-openabl-v1.1.patch"

SOCS=("${@:-sm8250 sm8550 sm8750}")
if [ "${#SOCS[@]}" -eq 1 ] && [[ "${SOCS[0]}" == *" "* ]]; then
  read -r -a SOCS <<< "${SOCS[0]}"
fi

mkdir -p "$(dirname "${OPENABL_DIR}")"
if [ ! -d "${OPENABL_DIR}/.git" ]; then
  git clone --branch "${OPENABL_TAG}" "${OPENABL_URL}" "${OPENABL_DIR}"
fi

cd "${OPENABL_DIR}"
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "==> OpenABL tree already has local modifications; keeping current working tree"
else
  git checkout -f "${OPENABL_TAG}"
  git apply "${PATCH_FILE}"
fi

if [ -f "${REPO_ROOT}/assets/ssalmon/HolodorSplashArt.h" ]; then
  cp -f "${REPO_ROOT}/assets/ssalmon/HolodorSplashArt.h" "${OPENABL_DIR}/Menu/HolodorSplashArt.h"
fi
if [ -f "${REPO_ROOT}/assets/ssalmon/HolodorWordmarkArt.h" ]; then
  cp -f "${REPO_ROOT}/assets/ssalmon/HolodorWordmarkArt.h" "${OPENABL_DIR}/View/HolodorWordmarkArt.h"
fi

./build.sh "${SOCS[@]}"

for soc in "${SOCS[@]}"; do
  upper="$(echo "${soc}" | tr '[:lower:]' '[:upper:]')"
  elf="build/out/abl_signed-${upper}.elf"
  pkg_dir="${REPO_ROOT}/packages/pocknix-bootloader-${soc}"
  if [ -f "${elf}" ] && [ -d "${pkg_dir}" ]; then
    cp -f "${elf}" "${pkg_dir}/abl_signed-${upper}.elf"
    cp -f "${elf}.sha256" "${pkg_dir}/abl_signed-${upper}.elf.sha256"
    echo "==> Updated ${pkg_dir}/abl_signed-${upper}.elf ($(cut -d' ' -f1 "${elf}.sha256"))"
  fi
done
