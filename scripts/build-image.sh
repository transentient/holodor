#!/usr/bin/env bash
# build-image.sh — build the complete pocknix-os ROOTFS (make build).
#
# Pipeline:
#   bootstrap -> configure pacman -> install packages (base + session lists) -> local pocknix
#   packages (incl. the linux-pocknix kernel) -> SM8550 firmware -> bake the native Steam client
#
# The output is a finished rootfs at ${ROOTFS_DIR}. Turning that into a flashable image
# (partitioning, boot KERNEL, first-boot config) is a SEPARATE step: scripts/build-sd-image.sh
# (make sd-image).

source "$(dirname "$0")/lib.sh"
need_linux
need_root build
for t in curl tar rsync sed; do need_tool "$t"; done

LOCAL_REPO_DIR="${LOCALREPO_DIR}"   # per-SoC: build/localrepo/${SOC} (set in lib.sh)

render_pacman_conf() {
  local out="$1"
  log "rendering pacman.conf (ALARM base)"
  cp -f "${CONFIG_DIR}/pacman.conf.in" "${out}"
}

# The local repo lives on the host; we bind-mount it to /localrepo inside the rootfs
# chroot, so the repo Server is that in-chroot path.
append_local_repo() {
  local out="$1"
  grep -q '^\[pocknix\]' "${out}" && return 0
  log "adding local pocknix repo"
  cat >> "${out}" <<EOF

[pocknix]
SigLevel = Never
Server = file:///localrepo
EOF
}

# Install the local [pocknix] packages into the rootfs: the shared core set
# (config/packages/pocknix-core.list), the emulation set (pocknix-emulation.list),
# the SoC kernel (${KERNEL_PKG}), then the device metapackage
# (devices/${DEVICE}/packages.list) which pulls the device BSP.
install_local_packages() {
  local root="$1"
  if [ ! -f "${LOCAL_REPO_DIR}/pocknix.db" ]; then
    warn "no local repo at ${LOCAL_REPO_DIR} (build-packages.sh didn't run?) — skipping local pkgs"
    return 0
  fi
  log "installing local pocknix packages (config/packages/pocknix-core.list + ${DEVICE} device set)"
  append_local_repo "${root}/etc/pacman.conf"
  mkdir -p "${root}/localrepo"
  mount --bind "${LOCAL_REPO_DIR}" "${root}/localrepo"
  chroot "${root}" pacman -Sy --noconfirm
  # The shared package set lives in config/packages/pocknix-core.list (per-package notes
  # there). Device packages (BSP + metapackage) come from devices/${DEVICE}/packages.list,
  # installed AFTER the kernel step below (the metapackage depends on the kernel package).
  #
  # QUALIFY every target with `pocknix/`: `pacman -S <name>` selects the FIRST repo in pacman.conf
  # order that has the name (NOT the highest version), and [pocknix] is appended LAST — so an
  # unqualified `gamescope`/`mangohud` would resolve to ALARM's [extra] copy (gamescope's vanilla
  # build black-screens the rotated panel; our patched mangohud has the Adreno reader). epoch=1 only
  # affects `-Syu` upgrades, not `-S` selection. Qualifying forces our builds and errors loudly if a
  # local package is genuinely missing from [pocknix] instead of silently grabbing ALARM's.
  # mesa-next + vulkan-freedreno-next: our epoch-2 trimmed/tuned 26.3.0-dev builds REPLACE the
  # ALARM mesa/vulkan-freedreno that base.list installed for bootstrap. The names now DIFFER
  # (the -next packages carry provides/conflicts on the plain names), so this is a conflict
  # replacement, not an upgrade — and plain --noconfirm answers NO to pacman's "remove mesa?"
  # prompt and aborts. --ask 4 flips the default for exactly that removal question to YES
  # (no-op when there is no conflict).
  local -a _pkgs=()
  local _p
  while read -r _p; do _pkgs+=("pocknix/${_p}"); done \
    < <(read_pkglist "${CONFIG_DIR}/packages/pocknix-core.list")
  chroot "${root}" pacman -S --noconfirm --ask 4 --needed "${_pkgs[@]}"
  # GUARD: these local builds MUST come from [pocknix], not silently fall back / go missing. gamescope
  # especially: ALARM's vanilla lacks --use-rotation-shader and black-screens on the RP6 (bitten 3x).
  local mesa_ver; mesa_ver="$(chroot "${root}" pacman -Q mesa-next 2>/dev/null | awk '{print $2}')"
  [ -n "${mesa_ver}" ] || mesa_ver="$(chroot "${root}" pacman -Q mesa 2>/dev/null | awk '{print $2}')"
  case "${mesa_ver}" in
    2:*) log "mesa OK: ${mesa_ver} (epoch-2 pocknix trimmed build)" ;;
    *) die "mesa resolved to '${mesa_ver}', NOT our epoch-2 [pocknix] build — the image would ship ALARM's all-driver mesa. Confirm build/localrepo/mesa-2:*.pkg.tar.* exists AND is in pocknix.db ('make packages PKG=mesa'), then re-run." ;;
  esac
  local gs_ver; gs_ver="$(chroot "${root}" pacman -Q gamescope 2>/dev/null | awk '{print $2}')"
  case "${gs_ver}" in
    1:*rocknix*) log "gamescope OK: ${gs_ver} (epoch-1 patched build)" ;;
    *) die "gamescope resolved to '${gs_ver}', NOT our epoch-1 [pocknix] rocknix build. Vanilla gamescope can't drive the RP6's rotated panel (no --use-rotation-shader) -> black screen. The install pins pocknix/gamescope, so reaching here means [pocknix] is missing it: confirm build/localrepo/gamescope-1:*.pkg.tar.* exists AND is registered in pocknix.db ('make packages PKG=gamescope' rebuilds + repo-adds it), then re-run." ;;
  esac
  local lp
  for lp in fex-emu fex-rootfs; do
    chroot "${root}" pacman -Q "${lp}" >/dev/null 2>&1 || {
      die "${lp} not installed — its local build wasn't in [pocknix]. Build it: 'make packages PKG=${lp}' (fex-rootfs downloads the ~1.1 GB Arch x86 squashfs once), confirm build/localrepo/${lp}-*.pkg.tar.* exists, then re-run."
    }
  done
  # pocknix-desktop must come from [pocknix] too (it pulls the Plasma Mobile stack from ALARM).
  chroot "${root}" pacman -Q pocknix-desktop >/dev/null 2>&1 || {
    die "pocknix-desktop not installed — its local build wasn't in [pocknix]. Build it: 'make packages PKG=pocknix-desktop', confirm build/localrepo/pocknix-desktop-*.pkg.tar.* exists, then re-run."
  }
  # Emulation layer (config/packages/pocknix-emulation.list): ES-DE frontend, vendored core
  # set, AppImage emulators. ALARM-side deps (retroarch, ppsspp, fuse2) came from
  # emulation.list above. Hard-required. NB: steam-rom-manager is NOT shipped — its Electron
  # CLI deadlocked on-device (2026-07-05) and the Steam-library sync is done by
  # pocknix-steam-sync (direct shortcuts.vdf write) instead; the PKGBUILD is retired to
  # packages/attic/ (outside the build glob — makepkg + pacman -U it manually if ever wanted).
  _pkgs=()
  while read -r _p; do _pkgs+=("pocknix/${_p}"); done \
    < <(read_pkglist "${CONFIG_DIR}/packages/pocknix-emulation.list")
  # HOLODOR: the emulation list may be fully commented (v0 is Steam-only) —
  # pacman errors on an empty target list.
  if [ ${#_pkgs[@]} -eq 0 ]; then
    log "pocknix-emulation.list is empty — skipping emulation set"
  else
    chroot "${root}" pacman -S --noconfirm --needed "${_pkgs[@]}"
  fi
  # Source-built emulators are OPTIONAL-warn (first-ever aarch64 builds = likeliest to fail; a
  # missing one just leaves that system out of ES-DE, which degrades gracefully) — don't fail the
  # whole image over 3DS/GameCube/WiiU.
  local oe
  for oe in dolphin-emu azahar cemu; do
    chroot "${root}" pacman -S --noconfirm --needed "pocknix/${oe}" 2>/dev/null \
      || warn "optional emulator ${oe} not in [pocknix] (build failed/skipped?) — image ships WITHOUT it"
  done
  # Kernel: swap ALARM's generic linux-aarch64 for our SoC kernel package (Image + modules,
  # built by `make kernel` -> staged into the package). Its own step (not bundled above) so a
  # missing kernel build errors clearly, and the replace is deterministic. `provides=linux`.
  if chroot "${root}" pacman -Si "pocknix/${KERNEL_PKG}" >/dev/null 2>&1; then
    chroot "${root}" pacman -Rdd --noconfirm linux-aarch64 2>/dev/null || true
    rm -rf "${root}/boot/initramfs-linux"*.img 2>/dev/null || true
    chroot "${root}" pacman -S --noconfirm "pocknix/${KERNEL_PKG}"
    chroot "${root}" pacman -Q "${KERNEL_PKG}" >/dev/null 2>&1 || {
      die "${KERNEL_PKG} failed to install — check the pacman output above."
    }
    log "kernel OK: $(chroot "${root}" pacman -Q "${KERNEL_PKG}")"
  else
    die "${KERNEL_PKG} not in [pocknix] — run 'make kernel' first (build-packages.sh stages build/kernel/out into the package), then re-run. Without it the rootfs has no matching modules for the booted kernel."
  fi
  # Device selection LAST: the per-device metapackage (devices/${DEVICE}/packages.list)
  # pins the device identity and pulls the BSP + the kernel package (already present).
  _pkgs=()
  while read -r _p; do _pkgs+=("pocknix/${_p}"); done \
    < <(read_pkglist "${DEVICE_DIR}/packages.list")
  chroot "${root}" pacman -S --noconfirm --needed "${_pkgs[@]}"
  # Resume-build staleness: everything above is `--needed` on EXPLICIT names, so a package
  # that only entered as a dependency (the BSP via the device metapackage) never upgrades
  # when its pkgrel is bumped — a resumed image silently ships the old build (this shipped
  # a dead-controls BSP once). Re-sync every INSTALLED package that [pocknix] carries:
  # --needed skips same-version, uninstalled ones (optional emulators) stay absent.
  _stale=()
  while read -r _p; do
    # pacman -Q resolves provides (asking for `mesa` answers `mesa-next`), so gate on the
    # EXACT installed name — else this loop re-adds the plain package its -next replacement
    # conflicts with and the transaction dies (bitten by the mesa-next driver swap).
    [ "$(chroot "${root}" pacman -Q "${_p}" 2>/dev/null | awk '{print $1}')" = "${_p}" ] \
      && _stale+=("pocknix/${_p}")
  done < <(chroot "${root}" pacman -Slq pocknix)
  [ "${#_stale[@]}" -gt 0 ] && chroot "${root}" pacman -S --noconfirm --needed "${_stale[@]}"
  chroot "${root}" pacman -Q "${DEVICE_BSP_PKG}" >/dev/null 2>&1 || {
    die "${DEVICE_BSP_PKG} not installed — the device metapackage should have pulled it. Check devices/${DEVICE}/packages.list and 'make packages'."
  }
  log "device OK: $(chroot "${root}" pacman -Q "${DEVICE_META_PKG}" 2>/dev/null || echo "${DEVICE}")"
  umount "${root}/localrepo"
  rmdir "${root}/localrepo" 2>/dev/null || true
  # Drop the build-only [pocknix] stanza (its file:///localrepo bind mount doesn't exist on
  # the device). With POCKNIX_REPO_URL set, re-add a stanza pointing at the PUBLISHED repo
  # (see docs/pacman-repo.md), inserted ABOVE [core]: `pacman -S <name>` picks the FIRST
  # repo that carries the name, so pocknix must outrank ALARM for our same-name packages
  # (mesa, gamescope, ...). Without it the image ships reflash-only, as before.
  sed -i '/^\[pocknix\]/,+2d' "${root}/etc/pacman.conf"
  # Per-SoC published repo: POCKNIX_REPO_URL is the BASE url; each SoC's tree
  # lives under it (tuned packages share pkgnames across SoCs with different
  # binaries, so the trees must not mix — see pocknix-notes dev/pacman-repo.md).
  if [ -n "${POCKNIX_REPO_URL}" ]; then
    log "shipping [pocknix] repo stanza -> ${POCKNIX_REPO_URL}/${SOC} (SigLevel ${POCKNIX_REPO_SIGLEVEL})"
    sed -i "0,/^\[core\]/s||[pocknix]\nSigLevel = ${POCKNIX_REPO_SIGLEVEL}\nServer = ${POCKNIX_REPO_URL}/${SOC}\n\n[core]|" \
      "${root}/etc/pacman.conf"
    # Trust the repo key out of the box: bake the exported public key + lsign it, so a
    # fresh image can `pacman -Syu` without a manual pacman-key dance.
    if [ -n "${POCKNIX_REPO_PUBKEY}" ]; then
      [ -f "${POCKNIX_REPO_PUBKEY}" ] || die "POCKNIX_REPO_PUBKEY not found: ${POCKNIX_REPO_PUBKEY}"
      install -Dm644 "${POCKNIX_REPO_PUBKEY}" "${root}/usr/share/pocknix/pocknix-repo.gpg"
      chroot "${root}" pacman-key --add /usr/share/pocknix/pocknix-repo.gpg
      local fpr
      fpr="$(gpg --show-keys --with-colons "${POCKNIX_REPO_PUBKEY}" 2>/dev/null | awk -F: '/^fpr/{print $10; exit}')"
      [ -n "${fpr}" ] || die "could not read the key fingerprint from ${POCKNIX_REPO_PUBKEY} (host gpg missing?)"
      chroot "${root}" pacman-key --lsign-key "${fpr}"
      log "repo key trusted: ${fpr}"
    fi
  fi
}

read_pkglist() {
  # One package per line, optional inline "# comment". Strip the comment and take the first
  # token: `sed 's/#.*//'` alone LEAVES the whitespace before the # (e.g. "vulkan-tools     "),
  # which pacman then can't match -> "target not found". awk $1 drops surrounding whitespace and
  # blank/comment-only lines cleanly.
  awk '{ sub(/#.*/, ""); if ($1 != "") print $1 }' "$1"
}

configure_keyring() {
  local root="$1"
  # HOLODOR: Holo Core preview packages are unsigned (SigLevel Optional) and
  # there is no archlinuxarm keyring in the rootfs — init only, no populate.
  if [ "${ROOTFS_FLAVOR:-holo}" = "holo" ]; then
    log "initialising pacman keyring (holo: init only, preview pkgs unsigned)"
    chroot "${root}" pacman-key --init
    return 0
  fi
  log "initialising pacman keyring (archlinuxarm)"
  chroot "${root}" pacman-key --init
  chroot "${root}" pacman-key --populate archlinuxarm
}

# Generate a UTF-8 locale (ALARM base is "C" only). Qt/Plasma warn + fall back to C.UTF-8 otherwise.
configure_locale() {
  local root="$1"
  log "generating en_US.UTF-8 locale"
  sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' "${root}/etc/locale.gen"
  chroot "${root}" locale-gen
  echo 'LANG=en_US.UTF-8' > "${root}/etc/locale.conf"
}

install_packages() {
  local root="$1"; shift
  local lists=("$@")
  local pkgs=()
  for l in "${lists[@]}"; do
    mapfile -t -O "${#pkgs[@]}" pkgs < <(read_pkglist "${l}")
  done
  log "installing ${#pkgs[@]} packages from: ${lists[*]##*/}"
  # On a RESUMED rootfs, drop any explicit target that is already satisfied by a DIFFERENT
  # installed package (pacman -Q resolves provides: asking for `mesa` answers `mesa-next`).
  # Keeping such a target would install the upstream package its replacement conflicts with.
  # Fresh builds are unaffected (nothing installed yet, -Q answers nothing).
  local _kept=() _p _owner
  for _p in "${pkgs[@]}"; do
    # NB: a NOT-yet-installed target makes `pacman -Q` exit 1; under pipefail that status leaks
    # out of the substitution and `set -e` silently aborts the build (bit us 2026-09-15 when
    # plasma-desktop was first added to a resumed rootfs). Empty owner = not installed = keep.
    _owner="$(chroot "${root}" pacman -Q "${_p}" 2>/dev/null | awk '{print $1}' || true)"
    if [ -n "${_owner}" ] && [ "${_owner}" != "${_p}" ]; then
      log "  skipping ${_p} (provided by installed ${_owner})"
    else
      _kept+=("${_p}")
    fi
  done
  pkgs=("${_kept[@]}")
  # -Syy (force DB refresh): a reused rootfs keeps a stale sync DB, and plain -Sy won't
  # re-download a DB pacman thinks is current -> valid extra pkgs (vulkan-tools, alsa-utils,
  # alsa-ucm-conf) show up as "target not found". Safe here: this is a fresh-image -Su anyway.
  chroot "${root}" pacman -Syyu --noconfirm --needed "${pkgs[@]}"
}

# Install the SoC device firmware (ath12k wifi board data, adsp/cdsp, vpu, ...)
# from ROCKNIX's synced overlay into the rootfs. The path comes from the device
# profile (FW_SRC_REL). It's a large synced vendor blob, so installed directly
# here rather than packaged (could become pocknix-firmware-<soc> later).
FW_SRC="${VENDOR_DIR}/${FW_SRC_REL}"
install_firmware() {
  local root="$1"
  if [ -d "${FW_SRC}" ] && [ -n "$(ls -A "${FW_SRC}" 2>/dev/null)" ]; then
    log "installing ${SOC} device firmware -> rootfs /usr/lib/firmware ($(du -sh "${FW_SRC}" | cut -f1))"
    mkdir -p "${root}/usr/lib/firmware"
    # --chown=root:root: the vendor firmware tree is owned by the host build user (uid 1000); plain
    # rsync -a would bake that into the rootfs as 'alarm'-owned firmware (and re-own /usr). Force root.
    rsync -a --chown=root:root "${FW_SRC}/" "${root}/usr/lib/firmware/"
  elif [ "${SOC}" = "sm8250" ]; then
    # Expected: ROCKNIX ships NO firmware overlay for SM8250 — every blob in
    # kernel/sm8250/config/kernel-firmware.dat (a650 GPU, adsp/cdsp, ath11k,
    # BT) comes from upstream linux-firmware, which ALARM's linux-firmware/
    # linux-firmware-qcom packages already put in the rootfs.
    log "no ${SOC} firmware overlay (expected: all blobs come from ALARM linux-firmware packages)"
  else
    # HOLODOR: SM8750 also ships NO overlay — its manifest blobs live in RECENT
    # upstream linux-firmware, which Holo Core's pinned snapshot predates (the
    # gen80000 A830 GPU firmware — shipped an image with no GPU once). Fetch
    # every manifest entry that the rootfs doesn't already have (checking the
    # .zst-compressed form Holo's packages use; the kernel loads either).
    # HOLODOR: ROCKNIX keeps the per-SoC vendor blobs (WCN7860 wifi, qca BT,
    # adsp/cdsp, audio topology, vpu) in a SEPARATE repo — ROCKNIX/extra-firmware,
    # under SM8750/**. They are NOT in upstream linux-firmware at all, so the
    # manifest reconcile below cannot supply them. Without these: no wifi, no BT,
    # no audio DSP (v0 shipped exactly that way).
    local xfw_rev="${ROCKNIX_EXTRA_FIRMWARE_REV:-99e17b0d20fe888ea3b4b100945724090533515f}"
    local xfw_tar="${CACHE_DIR}/rocknix-extra-firmware-${xfw_rev}.tar.gz"
    local xfw_dir="${BUILD_DIR}/extra-firmware-${xfw_rev}"
    if [ ! -d "${xfw_dir}/extra-firmware-${xfw_rev}/${ROCKNIX_SOC}" ]; then
      log "fetching ROCKNIX extra-firmware (${ROCKNIX_SOC} vendor blobs)"
      curl -fsSL --retry 3 -o "${xfw_tar}" \
        "https://github.com/ROCKNIX/extra-firmware/archive/${xfw_rev}.tar.gz" \
        || die "could not fetch ROCKNIX extra-firmware (wifi/bt/dsp firmware)"
      mkdir -p "${xfw_dir}"; tar -xzf "${xfw_tar}" -C "${xfw_dir}"
    fi
    local xfw_src="${xfw_dir}/extra-firmware-${xfw_rev}/${ROCKNIX_SOC}"
    if [ -d "${xfw_src}" ]; then
      log "installing ${ROCKNIX_SOC} vendor firmware ($(du -sh "${xfw_src}" | cut -f1)) -> rootfs"
      rsync -a --chown=root:root "${xfw_src}/" "${root}/usr/lib/firmware/"
    else
      die "ROCKNIX extra-firmware has no ${ROCKNIX_SOC}/ tree — wifi/bt/dsp would be missing"
    fi

    local dat="${KERNEL_DIR}/config/kernel-firmware.dat" fetched=0 missing=0 f
    if [ -f "${dat}" ]; then
      log "no ${SOC} firmware overlay — reconciling rootfs against ${dat} (fetching gaps from upstream linux-firmware)"
      while IFS= read -r f || [ -n "$f" ]; do
        f="$(echo "$f" | tr -d '[:space:]')"; [ -z "$f" ] && continue
        if [ -e "${root}/usr/lib/firmware/${f}" ] || [ -e "${root}/usr/lib/firmware/${f}.zst" ]; then
          continue
        fi
        mkdir -p "${root}/usr/lib/firmware/$(dirname "${f}")"
        if curl -fsSL --retry 3 --max-time 120 \
             -o "${root}/usr/lib/firmware/${f}" \
             "https://web.git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/${f}"; then
          chown root:root "${root}/usr/lib/firmware/${f}"; chmod 644 "${root}/usr/lib/firmware/${f}"
          log "  fetched ${f}"
          fetched=$((fetched+1))
        else
          warn "  could NOT fetch ${f} — device may lack this firmware"
          missing=$((missing+1))
        fi
      done < "${dat}"
      [ "${missing}" -gt 0 ] && die "firmware manifest incomplete (${missing} unfetchable) — refusing to build a blind image"
      log "firmware reconciled (${fetched} fetched)"
    else
      warn "ROCKNIX firmware overlay not at ${FW_SRC} and no manifest at ${dat} — wifi/gpu/audio firmware may be missing"
    fi
  fi
}

# NOTE: kernel integration (modules + Image, and replacing ALARM's linux-aarch64) is now done by
# the linux-pocknix PACKAGE, installed in install_local_packages() — no separate install_kernel().

# Bake the native ARM Steam client at BUILD time (armada's generate-steam-bootstrap model) so first
# boot needs no network (drops the Wi-Fi-preseed requirement). Runs the on-device installer in the
# rootfs chroot — which already has the steam deps + Xvfb — under a STAGING HOME, verifies the tree
# is complete (steamui.so + the channel .installed manifest, else the seed would re-install online),
# strips per-session cruft, and tars the HOME-agnostic tree (relative .steam symlinks) into a
# re-seedable seed cached at ${CACHE_DIR}/steam-seed.tar.zst. The tar is a BUILD-TIME INTERMEDIATE:
# we unpack it straight into the rootfs's /home/deck at the end of this function (see below) so the
# extracted tree is part of ROOTFS_DIR before build-sd-image.sh sizes the image partition, and the
# tar itself is never shipped. First boot then has no extract wait AND no network need.
# Cached in ${CACHE_DIR} so it runs once (POCKNIX_REBOOTSTRAP_STEAM=1 forces a rebake) — repeat
# builds reuse the cache and need no network. The bake is mandatory: the on-device launcher has no
# network-installer fallback, so a build with no seed would ship a Steam session that hard-fails.
bootstrap_steam_seed() {
  local root="$1"
  local seed="${CACHE_DIR}/steam-seed.tar.zst"
  local home="/var/lib/pocknix/steam-seed-home"
  local steam="${home}/.local/share/Steam"

  if [ ! -f "${seed}" ] || [ -n "${POCKNIX_REBOOTSTRAP_STEAM:-}" ]; then
    log "baking native ARM Steam client (downloads + Xvfb self-update; can take several minutes)..."
    # steam/bwrap need a real writable /dev/shm. chroot_mount binds host /dev (non-recursive), so the
    # chroot has none. Make the chroot's /dev private FIRST so this tmpfs can't propagate up and
    # shadow the HOST's /dev/shm (the bind aliases the same path), then mount a private tmpfs.
    mount --make-rprivate "${root}/dev" 2>/dev/null || true
    mount -t tmpfs tmpfs "${root}/dev/shm"
    # HOLODOR: only wipe the seed home on an explicit clean rebake — the die
    # message below promises "the bake is cached, so a retry resumes", and an
    # unconditional wipe made that a lie (every retry re-downloaded ~1GB).
    if [ "${POCKNIX_REBOOTSTRAP_STEAM:-0}" = "1" ]; then
      chroot "${root}" rm -rf "${home}"
    fi
    chroot "${root}" mkdir -p "${home}"
    if ! chroot "${root}" env HOME="${home}" /usr/bin/pocknix-steam-install; then
      umount "${root}/dev/shm" 2>/dev/null || true
      die "steam bake failed (pocknix-steam-install in chroot). Check network + retry (the bake is cached, so a retry resumes)."
    fi
    if ! chroot "${root}" test -f "${steam}/steamrtarm64/steamui.so" \
       || ! chroot "${root}" test -f "${steam}/package/steam_client_steamdeck_stable_linuxarm64.installed"; then
      umount "${root}/dev/shm" 2>/dev/null || true
      # HOLODOR: the in-chroot Xvfb self-update never writes the .installed
      # manifest on SD-card build hosts (>1h, deterministic). The client tree +
      # runtime are present; without the manifest Steam simply re-verifies /
      # finishes its layout on first boot (post-OOBE, real network) — the
      # SteamOS-like OOBE covers that path anyway. Allow shipping that seed.
      if [ "${HOLODOR_ALLOW_INCOMPLETE_BAKE:-0}" = "1" ] \
         && chroot "${root}" test -f "${steam}/steamrtarm64/steamui.so"; then
        warn "DANGER: shipping an UNFINALIZED steam seed — this caused an unrecoverable Steam update loop on v0"
      else
        die "steam bake incomplete (no steamui.so / .installed) — the seed is broken. Re-run (POCKNIX_REBOOTSTRAP_STEAM=1 forces a clean rebake)."
      fi
    fi
    # strip per-session cruft AND registry.vdf (like armada) so the seed shows the OOBE on first boot
    # — the user configures Wi-Fi there; pocknix-steamos-shim's steamos-update keeps the OOBE's
    # required-update step from dead-ending. Then tar the HOME-agnostic tree.
    chroot "${root}" bash -c "set -e; cd '${home}'
      rm -rf .local/share/Steam/logs .local/share/Steam/appcache/httpcache \
             .local/share/Steam/appcache/cefdata .local/share/Steam/config/htmlcache
      find . \( -name '*.log' -o -name '*.pid' -o -name '*.token' -o -name '*.crash' \) -delete
      find . \( -type s -o -type p \) -delete
      rm -f .local/share/Steam/ssfn* .local/share/Steam/registry.vdf \
            .steam/registry.vdf .steam/steam.pid .steam/steam.token
      tar -caf /steam-seed.tar.zst .local .steam"
    mkdir -p "${CACHE_DIR}"; cp "${root}/steam-seed.tar.zst" "${seed}"
    chroot "${root}" rm -f /steam-seed.tar.zst; chroot "${root}" rm -rf "${home}"
    umount "${root}/dev/shm" 2>/dev/null || true
    ok "steam seed baked: ${seed} ($(du -h "${seed}" | cut -f1))"
  else
    log "using cached steam seed: ${seed} ($(du -h "${seed}" | cut -f1))"
  fi
  # Pre-extract the baked client into the rootfs's /home/deck HERE — while it's still part of
  # ROOTFS_DIR, so build-sd-image.sh's `du -sm ROOTFS_DIR` sizes the image partition to INCLUDE the
  # ~1.3 GB tree. (Extracting later, during image assembly into the already-sized partition, blew
  # past its size -> "No space left on device".) The tar is NOT shipped in the rootfs: we unpack the
  # cached seed straight in and drop it, so the image carries only the extracted tree. Files land
  # root-owned (bake ran as root); build-sd-image.sh creates the deck user (uid 1001) and its
  # `chown -R deck:deck /home/deck` fixes ownership. The relative .steam symlinks are HOME-agnostic
  # so they resolve correctly once this tree is deck's HOME.
  log "pre-extracting Steam client into rootfs /home/deck (sized into the partition; no tar shipped)"
  install -d "${root}/home/deck"
  cp "${seed}" "${root}/steam-seed.tar.zst"
  chroot "${root}" bash -c "set -e; tar -C /home/deck -xf /steam-seed.tar.zst; rm -f /steam-seed.tar.zst"
}

main() {
  # 1. base rootfs
  # HOLODOR: resumable builds — Valve's preview CDN times out sporadically, and
  # every phase below is idempotent (pacman --needed, guarded bake, cp overlays).
  # Set HOLODOR_RESUME=1 to reuse the existing extracted rootfs instead of
  # re-extracting (which would discard the pacman cache and completed installs).
  if [ "${HOLODOR_RESUME:-0}" = "1" ] && [ -x "${ROOTFS_DIR}/usr/bin/pacman" ]; then
    log "resuming with existing rootfs (HOLODOR_RESUME=1): ${ROOTFS_DIR}"
  else
    "${POCKNIX_ROOT}/scripts/bootstrap.sh"
  fi

  # 1b. build the local pocknix-* packages (own build chroot) -> build/localrepo
  # HOLODOR: skippable when the localrepo is already complete — the full-catalog
  # refresh retries previously-failed packages (es-de → a 4h wxwidgets compile)
  # that the image doesn't install. Set HOLODOR_SKIP_PKGPHASE=1 to trust the
  # existing localrepo (build_local_pkgs still dies if the kernel pkg is absent).
  if [ "${HOLODOR_SKIP_PKGPHASE:-0}" = "1" ]; then
    log "skipping package-refresh phase (HOLODOR_SKIP_PKGPHASE=1 — using existing localrepo)"
  else
    "${POCKNIX_ROOT}/scripts/build-packages.sh"
  fi

  # 2. pacman config + repos inside the rootfs
  mkdir -p "${LOCAL_REPO_DIR}"
  render_pacman_conf "${ROOTFS_DIR}/etc/pacman.conf"

  trap 'umount "${ROOTFS_DIR}/localrepo" 2>/dev/null || true; chroot_umount "${ROOTFS_DIR}"' EXIT
  chroot_mount "${ROOTFS_DIR}"
  configure_keyring "${ROOTFS_DIR}"

  # 3. packages: base + the two session lists (steam = Phase 3 gamescope/mangohud; desktop = Phase 4
  #    Plasma Mobile). All from ALARM (no holo needed) — see config/packages/steam.list. Installed in
  #    ONE transaction so the (forced -Syy) repo-DB refresh happens once, not once per list.
  install_packages "${ROOTFS_DIR}" \
        "${CONFIG_DIR}/packages/base.list" \
        "${CONFIG_DIR}/packages/steam.list" \
        "${CONFIG_DIR}/packages/desktop.list" \
        "${CONFIG_DIR}/packages/emulation.list"

  # Generate a UTF-8 locale. The ALARM base ships only "C"; Qt apps (all of Plasma) warn and fall
  # back to C.UTF-8 on every launch, and the C path is slower. Set en_US.UTF-8 system-wide.
  configure_locale "${ROOTFS_DIR}"

  # 4. device support (Phase 2): SM8550 firmware + pocknix-bsp (suspend hooks etc.).
  #    The kernel (linux-pocknix: Image + modules, replacing ALARM's linux-aarch64) is installed
  #    inside install_local_packages from build/kernel/out — run `make kernel` first.
  install_firmware "${ROOTFS_DIR}"
  install_local_packages "${ROOTFS_DIR}"

  # 5. bake the native ARM Steam client into a re-seedable seed (offline first boot).
  #    HOLODOR_SEEDLESS=1 skips it: the image ships NO Valve client (the public-release
  #    mode — no redistribution exposure) and pocknix-steam-bootstrap downloads it on the
  #    device at first boot instead (see docs/steam-bootstrap-design.md). Dev images keep
  #    the seed by default for fast iteration.
  if [ "${HOLODOR_SEEDLESS:-0}" = "1" ]; then
    log "HOLODOR_SEEDLESS=1 — skipping the Steam seed bake (client downloads on first boot)"
  else
    bootstrap_steam_seed "${ROOTFS_DIR}"
  fi

  chroot_umount "${ROOTFS_DIR}"; trap - EXIT

  # The rootfs is complete. Assembling it into a flashable image (partitions, boot KERNEL,
  # first-boot config) is a separate step: scripts/build-sd-image.sh (make sd-image).
  ok "build-image: rootfs ready at ${ROOTFS_DIR} — run 'make sd-image' to assemble a flashable image"
}

main "$@"
