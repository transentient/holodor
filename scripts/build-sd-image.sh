#!/usr/bin/env bash
# build-sd-image.sh — assemble a flashable SD image to boot-test pocknix WITHOUT
# touching internal ROCKNIX. Layout mirrors ROCKNIX's SD for the SoC's
# BOOTLOADER style so the device's existing (ROCKNIX-flashed) ABL boots it:
#
#   GPT  p1  fat32  name "${SD_BOOT_PARTNAME}" (label ${SD_FAT_LABEL})  -> /KERNEL [+ GRUB]
#        p2  ext4   name "${ROOT_LABEL}"                                -> Arch base rootfs
#
# qcom-abl (sm8550): ABL loads /KERNEL (Android boot image, cmdline baked in).
# arm-efi  (sm8250): the factory ABL chainloads /EFI/BOOT/bootaa64.efi ->
#   /boot/grub/grub.cfg -> "linux /KERNEL" (raw Image) + "devicetree
#   /boot/grub/<board>.dtb"; the FAT additionally carries EFI/ and boot/grub/
#   (cfg + grubenv + dtbs). ROCKNIX sets legacy_boot on p1 for BOTH styles (no esp flag).
# Either way our kernel mounts its root directly by PARTUUID (fixed SD GUIDs; no
# initramfs — UFS/ext4 are built in). ROCKNIX also puts a SYSTEM squashfs on
# the FAT; we don't need it (plain ext4 root).
#
# Prereqs: `sudo make build` (rootfs) + `make kernel` (KERNEL). Run as root (loop+mount).
# Flash:   sudo dd if=build/image/<soc>/pocknix-<soc>-sd.img of=/dev/sdX bs=4M conv=fsync status=progress

source "$(dirname "$0")/lib.sh"
need_linux
need_root sd-image
for t in parted sgdisk mkfs.vfat mkfs.ext4 losetup rsync chroot truncate du; do need_tool "$t"; done   # sgdisk: gptfdisk pkg

KERNEL_IMG="${IMAGE_DIR}/KERNEL"
KOUT="${KERNEL_BUILD_DIR}/out"   # per-SoC (set in lib.sh)
OUT="${IMAGE_DIR}/pocknix-${SOC}-sd.img"   # one image per SoC family -> name it so

[ -f "${KERNEL_IMG}" ] || die "no ${KERNEL_IMG} — run 'make kernel' first"
[ -d "${ROOTFS_DIR}" ] || die "no rootfs at ${ROOTFS_DIR} — run 'sudo make build' first"

# Rootfs integrity: a rootfs copied between hosts WITHOUT root (rsync/scp as a user) silently
# drops every root-only file (/etc/shadow is 600) and re-owns everything to the copying user —
# chpasswd then dies mid-build with the opaque "Authentication token manipulation error", and a
# rootfs like that is unshippable anyway. Catch it up front with a clear message.
[ -f "${ROOTFS_DIR}/etc/shadow" ] \
  || die "rootfs has no /etc/shadow — it was copied without root and is missing root-only files. Rebuild it: 'sudo scripts/build-image.sh' (HOLODOR_SKIP_PKGPHASE=1 keeps the localrepo)."
[ "$(stat -c %u "${ROOTFS_DIR}/etc/passwd")" = "0" ] \
  || die "rootfs /etc/passwd is not root-owned — the rootfs ownership is corrupt (non-root copy?). Rebuild it: 'sudo scripts/build-image.sh' (HOLODOR_SKIP_PKGPHASE=1 keeps the localrepo)."

LOOP=""; MNT=""
cleanup() {
  [ -n "${MNT}" ] && mountpoint -q "${MNT}" && umount "${MNT}" 2>/dev/null || true
  [ -n "${MNT}" ] && rmdir "${MNT}" 2>/dev/null || true
  [ -n "${LOOP}" ] && losetup -d "${LOOP}" 2>/dev/null || true
}
trap cleanup EXIT

# Make sure the rootfs carries the pocknix kernel modules + drops the generic
# ALARM kernel, in case `make build` ran before the kernel existed (idempotent).
ensure_kernel_in_rootfs() {
  # SoC marker sanity (kernel outputs are per-SoC dirs now, so this should never
  # fire — kept as cheap insurance against manual copies/renames)
  if [ -f "${KOUT}/soc" ] && [ "$(cat "${KOUT}/soc")" != "${SOC}" ]; then
    die "${KOUT} was built for SOC=$(cat "${KOUT}/soc"), not ${SOC} — run 'make kernel DEVICE=${DEVICE}' first"
  fi
  if [ -d "${KOUT}/modroot/lib/modules" ]; then
    local kver; kver="$(cat "${KOUT}/kernelrelease" 2>/dev/null)"
    log "syncing pocknix modules (${kver}) into rootfs + removing generic kernel"
    chroot "${ROOTFS_DIR}" pacman -Rdd --noconfirm linux-aarch64 2>/dev/null || true
    # --chown=root:root: the kernel build output is owned by the host build user (uid 1000), and
    # plain rsync -a preserves that — which inside the ALARM rootfs is 'alarm', not root. Force root.
    rsync -a --chown=root:root "${KOUT}/modroot/lib/modules/" "${ROOTFS_DIR}/usr/lib/modules/"
    [ -n "${kver}" ] && chroot "${ROOTFS_DIR}" depmod "${kver}" 2>/dev/null || true
  else
    warn "no kernel modules in ${KOUT} — rootfs may lack matching modules"
  fi
}

# arm-efi boot partition contents beyond /KERNEL: GRUB + grub.cfg/grubenv +
# every board dtb + the ROCKNIX ABL payload. All of it except the dtbs is
# shipped in the rootfs by pocknix-bootloader-${SOC} (single source of truth:
# its alpm hook refreshes /flash from the same tree on upgrades); the dtbs come
# from the kernel build (grub.cfg references /boot/grub/<board>.dtb).
populate_arm_efi_boot() {
  local mnt="$1" bl="${ROOTFS_DIR}/usr/share/pocknix/bootloader"
  [ -f "${bl}/EFI/BOOT/bootaa64.efi" ] \
    || die "arm-efi: ${bl#${ROOTFS_DIR}}/EFI/BOOT/bootaa64.efi missing from the rootfs — is pocknix-bootloader-${SOC} built and installed? (make packages + make build)"
  [ -f "${bl}/boot/grub/grub.cfg" ] \
    || die "arm-efi: ${bl#${ROOTFS_DIR}}/boot/grub/grub.cfg missing from the rootfs"
  rsync -a "${bl}/EFI" "${bl}/boot" "${mnt}/"
  cp "${KOUT}/dtbs/"*.dtb "${mnt}/boot/grub/"
}

# qcom-abl boot partition contents beyond /KERNEL: the ROCKNIX ABL folder
# (signed ELF + the Android-side backup/flash/restore scripts), shipped in the
# rootfs by pocknix-bootloader-${SOC} at /usr/share/bootloader/rocknix_abl —
# the same place ROCKNIX keeps it, so kernel/${SOC}/bootloader/update.sh
# refreshes /flash from it on updates. The user reads the folder off the SD
# from Android to flash the bootloader; it is the only way a fresh user gets
# the scripts (the ROCKNIX GitHub release holds ELFs only). Required on
# sm8750; absent on sm8550 (its ABL predates the folder) so only warn there.
populate_qcom_abl_boot() {
  local mnt="$1" bl="${ROOTFS_DIR}/usr/share/bootloader/rocknix_abl"
  if [ ! -d "${bl}" ]; then
    [ "${SOC}" = "sm8750" ] && die "qcom-abl: ${bl#${ROOTFS_DIR}} missing from the rootfs — is pocknix-bootloader-${SOC} built and installed? (make packages PKG=pocknix-bootloader-${SOC} + make build)"
    warn "no ${bl#${ROOTFS_DIR}} in the rootfs — SD boot FAT ships without the ROCKNIX ABL folder"
    return 0
  fi
  mkdir -p "${mnt}/rocknix_abl"
  cp "${bl}"/* "${mnt}/rocknix_abl/"
  log "SD boot FAT: rocknix_abl/ ($(ls "${mnt}/rocknix_abl" | wc -l) files, ABL $(sha256sum "${mnt}/rocknix_abl/abl_signed-${SOC^^}.elf" 2>/dev/null | cut -c1-12))"
}

firstboot_config() {
  local root="$1"
  log "configuring first boot (root login, fstab, ssh, network, hostname)"
  if [ "${HOLODOR_RELEASE:-0}" = "1" ]; then
    # RELEASE (Steam Deck model): no credential exists at all — password deleted, so
    # console/desktop login works and `passwd` lets the owner set their own; sshd is
    # not enabled (below), so there is no remote surface until the owner opts in.
    chroot "${root}" passwd -d root >/dev/null
  else
    echo "root:${SD_ROOT_PASSWORD}" | chroot "${root}" chpasswd
  fi
  cat > "${root}/etc/fstab" <<EOF
# pocknix-os test image
# noatime: no software here needs atime; dropping atime write-backs cuts flash writes (SteamOS/ROCKNIX do the same).
PARTUUID=${SD_ROOT_PARTUUID}  /       ext4  rw,noatime         0 1
PARTUUID=${SD_BOOT_PARTUUID}  /flash  vfat  rw,noatime,nofail  0 2
EOF
  echo "${SD_HOSTNAME:-holodor}" > "${root}/etc/hostname"
  # Default timezone: the ALARM base ships NO /etc/localtime, so libc (and thus the SteamOS/Plasma
  # clock) silently falls back to UTC and changing the zone in the UI "has no effect" — there's no
  # file for it to land in. Ship a default symlink (overridable via SD_TIMEZONE); the user can change
  # it in the OOBE / Settings (deck is authorised via overlay 50-pocknix-deck.rules -> timedate1).
  chroot "${root}" ln -sfn "/usr/share/zoneinfo/${SD_TIMEZONE:-UTC}" /etc/localtime
  # The Odin 3's RTC is VOLATILE — every cold boot starts at the epoch. systemd-timesyncd
  # floors the boot clock to its saved clock file's mtime, but a FRESH image has no such
  # file, so the very first boot runs at a bogus date until the first NTP sync — which
  # breaks every TLS connection (hardware-observed: Steam login "connection problem", QR
  # spinner forever). Seed the file with the BUILD time so first boot starts within hours
  # of reality instead of at the systemd epoch.
  install -d -m 755 "${root}/var/lib/systemd/timesync"
  touch "${root}/var/lib/systemd/timesync/clock"
  chroot "${root}" chown -R systemd-timesync:systemd-timesync /var/lib/systemd/timesync 2>/dev/null \
    || warn "could not chown timesync clock seed (systemd-timesync user missing?)"
  if [ -f "${root}/etc/ssh/sshd_config" ]; then
    if [ "${HOLODOR_RELEASE:-0}" != "1" ]; then
      sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' "${root}/etc/ssh/sshd_config"
    fi
  fi

  # DEV-ONLY Wi-Fi preseed: any *.nmconnection in config/local/ (GITIGNORED — holds the PSK)
  # is baked in so a dev image comes up on the network without OOBE — invaluable while the
  # session is unstable and SSH is the only debug path. Release/polished images: empty the
  # directory first (known open work).
  if [ "${HOLODOR_RELEASE:-0}" = "1" ] && compgen -G "${POCKNIX_ROOT}/config/local/*.nmconnection" >/dev/null; then
    log "RELEASE build: refusing to bake config/local Wi-Fi profiles (dev-only)"
  elif compgen -G "${POCKNIX_ROOT}/config/local/*.nmconnection" >/dev/null; then
    log "preseeding Wi-Fi profiles from config/local/ (DEV image — not for release)"
    install -d -m 755 "${root}/etc/NetworkManager/system-connections"
    install -m 600 -o root -g root "${POCKNIX_ROOT}"/config/local/*.nmconnection \
      "${root}/etc/NetworkManager/system-connections/"
  fi

  # install the committed test-image overlay (diag dump, autologin, NM conf, fan/volume helpers)
  if [ -d "${POCKNIX_ROOT}/overlay" ]; then
    log "installing overlay (diag + autologin + helpers)"
    # --chown=root:root is REQUIRED: the overlay lives in the host git checkout owned by the build
    # user (uid 1000). Plain rsync -a preserves that ownership AND stamps the destination parent dirs
    # it touches (/, /usr, /etc/systemd, /etc/polkit-1, /root) — inside the ALARM rootfs uid 1000 is
    # 'alarm', not root. That silently broke privilege-bounded services: systemd-timedated runs as root
    # but with CapabilityBoundingSet=CAP_SYS_TIME (no DAC_OVERRIDE), so it couldn't write /etc/localtime
    # when /etc was alarm-owned -> "set timezone has no effect". Force every overlay path to root:root.
    rsync -a --chown=root:root "${POCKNIX_ROOT}/overlay/" "${root}/"
    chmod +x "${root}/usr/local/bin/pocknix-diag" \
             "${root}/usr/local/bin/pocknix-expand-root" "${root}/usr/local/bin/pocknix-fancontrol" \
             "${root}/usr/local/bin/pocknix-volumed" "${root}/usr/local/bin/pocknix-powerd" \
             "${root}/usr/local/bin/pocknix-install-internal" \
             "${root}/usr/local/bin/pocknix-uninstall-internal" 2>/dev/null || true
  fi

  # --- non-root 'deck' session user ---
  # PipeWire refuses to run as root (ConditionUser=!root), so audio ("no output devices detected" in
  # Steam) only works for a normal user; bwrap/pressure-vessel (Proton) prefer non-root too. uid 1001
  # (ALARM ships 'alarm' at 1000). Groups: video/render (GPU), input (gamepad), audio, seat (seatd),
  # wheel (polkit admin via 50-pocknix-deck.rules). The overlay (rsync'd above) already placed
  # /home/deck/.bash_profile (boot-to-Steam) + the tty1 autologin=deck drop-in; useradd -m reuses
  # that home, then we chown it.
  log "creating non-root 'deck' session user (audio + Proton need a normal user)"
  chroot "${root}" useradd -m -u 1001 -U -s /bin/bash -G video,render,input,audio,seat,wheel deck 2>/dev/null || true
  if [ "${HOLODOR_RELEASE:-0}" = "1" ]; then
    chroot "${root}" passwd -d deck >/dev/null
  else
    echo "deck:${SD_DECK_PASSWORD:-${SD_ROOT_PASSWORD}}" | chroot "${root}" chpasswd
  fi
  # XDG user dirs in deck's home (Dolphin "Places", file dialogs, screenshots, downloads expect
  # these). The xdg-user-dirs package (desktop.list) also writes ~/.config/user-dirs.dirs at first
  # login so XDG_PICTURES_DIR etc. resolve, but create them here so they exist from first boot.
  for d in Desktop Documents Downloads Music Pictures Videos; do
    mkdir -p "${root}/home/deck/${d}"   # ownership fixed by the chown below ('deck' is unknown to the host)
  done
  # One chown covers everything under /home/deck: the XDG dirs just made, the overlay's .bash_profile/
  # .config, AND the Steam tree pre-extracted into it by build-image.sh (all root-owned until now).
  chroot "${root}" chown -R deck:deck /home/deck
  # NB: on SEEDED images the native Steam client is already pre-extracted into /home/deck by
  # build-image.sh's bootstrap_steam_seed (done there so `du -sm ROOTFS_DIR` above sizes the
  # partition to fit the ~1.3 GB tree). The chown above (root -> deck) is what gives deck
  # ownership of it. Guard both modes: a seeded build with a missing tree is a broken/stale
  # rootfs; a HOLODOR_SEEDLESS=1 build must NOT carry a leftover seed (that's the exact
  # redistribution exposure seedless exists to remove) — pocknix-steam-bootstrap downloads
  # the client on-device at first boot instead.
  if [ "${HOLODOR_SEEDLESS:-0}" = "1" ]; then
    [ ! -e "${root}/home/deck/.local/share/Steam" ] \
      || die "HOLODOR_SEEDLESS=1 but a Steam tree exists in the rootfs (/home/deck/.local/share/Steam) — rebuild the rootfs seedless ('sudo HOLODOR_SEEDLESS=1 make build') before assembling the image."
  else
    [ -x "${root}/home/deck/.local/share/Steam/steamrtarm64/steam" ] \
      || die "Steam client not pre-extracted in the rootfs (/home/deck/.local/share/Steam) — run 'sudo make build' first."
  fi

  # PipeWire/WirePlumber for deck's session (global-enable so its --user units start on login).
  chroot "${root}" systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true
  # Root services: RP6 fan curve + FEX-binfmt-off (deck can't write /proc/sys/fs/binfmt_misc) +
  # the volume-rocker handler (Steam shows the OSD but doesn't change volume on KEY_VOLUME*) +
  # gamescope-rt (RRs the compositor from root — the deck session has no rtprio grant, the
  # SteamOS model; see limits.d/60-pocknix-gaming.conf. Replaces the old rt-demote watcher).
  chroot "${root}" systemctl enable pocknix-fancontrol.service pocknix-fex-binfmt.service \
        pocknix-volumed.service pocknix-gamescope-rt.service pocknix-powerd.service 2>/dev/null || true
  # Power mode: re-apply the mode persisted by Pocknix Control (eco/balanced/performance) at boot.
  # Was never enabled before 2026-09-07, so a chosen mode silently reverted to uncapped on every
  # boot; bsp-common-19's helper also turns a persisted bench-only `max` into balanced here.
  chroot "${root}" systemctl enable pocknix-power-mode.service 2>/dev/null || true
  # Decky Loader (QAM plugins, incl. Pocknix Control): seed deck's ~/homebrew at boot, then run
  # the loader under FEX in its private-binfmt namespace (see packages/pocknix-decky).
  chroot "${root}" systemctl enable pocknix-decky-sync.service pocknix-decky-loader.service 2>/dev/null || true
  # Desktop (Plasma Mobile) session: register the Flathub remote on the first online boot so
  # Discover/flatpak can install apps. Harmless in game-only use (oneshot, no-op once added).
  chroot "${root}" systemctl enable pocknix-flathub.service 2>/dev/null || true
  # Splash-hold: keep plymouth (holding the badge frame) up THROUGH session start.
  # The session supervisor (deck .bash_profile) releases it with --retain-splash
  # right before gamescope takes DRM — closing the ~20s black boot gap. getty@tty1
  # starts underneath the splash (its After=plymouth-quit-wait ordering is moot
  # once these units have no job queued).
  chroot "${root}" systemctl disable plymouth-quit.service plymouth-quit-wait.service 2>/dev/null || true
  # Waydroid: re-assert the Android /data tuning (nav/density/font/immersive/multi_windows)
  # after each container boot — those settings are wiped by `waydroid init`. See docs/waydroid.md.
  chroot "${root}" systemctl enable pocknix-waydroid-tuning.service 2>/dev/null || true

  # Wi-Fi pre-seed — SteamOS topology: NetworkManager is the FRONT-END (Steam's gamepadui manages
  # Wi-Fi ONLY through NM's D-Bus API — without it the setup wizard shows "no connections found"
  # even when online), with iwd as the Wi-Fi BACKEND. NM owns IP config (DHCP/DNS) and MANAGES
  # wlan0; iwd does the 802.11 association. Credentials live in an NM keyfile so they show up in
  # Steam's network UI. iwd must NOT do its own netconfig here (EnableNetworkConfiguration=false),
  # else it fights NM for DHCP on wlan0 (the conflict that forced the old iwd-direct model).
  #
  # The static NM conf comes from the OVERLAY (rsync'd above): conf.d/20-wifi-backend.conf
  # (wifi.backend=iwd). Here we only write the build-var-dependent bits: iwd regdom + the NM
  # connection keyfile.
  install -d -m 755 "${root}/etc/NetworkManager/conf.d"
  # iwd = backend only: keep regdom Country (5 GHz) but turn its own netconfig OFF.
  install -d -m 755 "${root}/etc/iwd"
  {
    echo "[General]"
    [ -n "${SD_WIFI_COUNTRY}" ] && echo "Country=${SD_WIFI_COUNTRY}"
    echo "EnableNetworkConfiguration=false"
    # Conservative roaming: both 08-26 wifi sulks were roam-triggered at strong
    # signal (post-roam ath12k deauth + recovery gap). Hold the current BSS until
    # the signal is genuinely weak. The Critical pair defaults to -80/-82 and
    # overrides BSS affinity BEFORE the main thresholds — must be set lower too.
    # Hardware-validated on the Odin 3, 2026-08-28.
    echo "RoamThreshold=-85"
    echo "RoamThreshold5G=-85"
    echo "CriticalRoamThreshold=-90"
    echo "CriticalRoamThreshold5G=-90"
    # Roams are what crash the WCN7860 firmware post-resume (09-03 root cause; iwd 3.12
    # source verified in docs/wifi-roam-crash-research.md). DisableRoamingScan gates BOTH
    # low-RSSI and 802.11v BTM-directed roams; the RoamThreshold keys alone don't stop BTM.
    # Bias the initial pick toward 5 GHz so "stuck on the first BSS" is the good BSS.
    echo "[Scan]"
    echo "DisableRoamingScan=true"
    echo "[Rank]"
    echo "BandModifier5GHz=1.2"
  } > "${root}/etc/iwd/main.conf"
  # UPower brownout policy: the stock Critical=5/Action=2/HybridSleep trio let the device
  # SUSPEND at 3% and die entering suspend (09-02 00:51, gauge wrecked). No swap here, so
  # HybridSleep is meaningless; power off cleanly at 5% instead. UPower has no drop-in dir.
  if [ -f "${root}/etc/UPower/UPower.conf" ]; then
    sed -i -e 's/^PercentageAction=.*/PercentageAction=5.0/' \
           -e 's/^CriticalPowerAction=.*/CriticalPowerAction=PowerOff/' "${root}/etc/UPower/UPower.conf"
  fi
  # NM integrates DNS via systemd-resolved; point glibc at resolved's stub.
  ln -sf /run/systemd/resolve/stub-resolv.conf "${root}/etc/resolv.conf"

  # The ALARM base ships systemd-networkd ENABLED, but pocknix networking is
  # NetworkManager(+iwd): networkd manages no interfaces, so its enabled
  # wait-online blocks network-online.target for its full 120s timeout on EVERY
  # boot — stalling multi-user.target and everything ordered after it
  # (fancontrol, diag, decky all started ~2 minutes late; found on the RP5
  # bring-up, but every image paid it). systemd-resolved stays (NM uses it).
  chroot "${root}" systemctl disable systemd-networkd.service systemd-networkd.socket \
        systemd-networkd-wait-online.service \
        systemd-networkd-varlink.socket systemd-networkd-resolve-hook.socket \
        systemd-networkd-varlink-metrics.socket >/dev/null 2>&1 || true
  # disable is NOT enough for wait-online: anything wanting network-online.target pulls
  # it back in and it fails every boot (networkd manages no links). Mask it — NM's own
  # NetworkManager-wait-online serves that target.
  chroot "${root}" systemctl mask systemd-networkd-wait-online.service >/dev/null 2>&1 || true

  if [ -n "${SD_WIFI_SSID}" ]; then
    # Guard: a Wi-Fi SSID with no password silently ships an unusable image (the SSID is logged but
    # an empty PSK only surfaces as a boot-time association failure). Fail the build instead.
    [ -n "${SD_WIFI_PSK}" ] || die "SD_WIFI_SSID='${SD_WIFI_SSID}' is set but SD_WIFI_PSK is empty. Pass SD_WIFI_PSK='<password>' (note: 'sudo VAR=… make' must not drop it)."
    log "pre-seeding Wi-Fi (NetworkManager + iwd backend) for SSID '${SD_WIFI_SSID}'${SD_WIFI_COUNTRY:+, country ${SD_WIFI_COUNTRY}}"
    install -d -m 700 "${root}/etc/NetworkManager/system-connections"
    cat > "${root}/etc/NetworkManager/system-connections/${SD_WIFI_SSID}.nmconnection" <<EOF
[connection]
id=${SD_WIFI_SSID}
type=wifi
interface-name=wlan0
autoconnect=true

[wifi]
mode=infrastructure
ssid=${SD_WIFI_SSID}

[wifi-security]
key-mgmt=wpa-psk
psk=${SD_WIFI_PSK}

[ipv4]
method=auto

[ipv6]
method=auto
EOF
    chmod 600 "${root}/etc/NetworkManager/system-connections/${SD_WIFI_SSID}.nmconnection"

    # Provision the credential DIRECTLY into iwd (KnownNetwork) too. NetworkManager 1.56's iwd
    # backend does NOT hand the keyfile PSK to iwd — activation dead-ends at
    # need-auth/no-secrets ("No agents were available"), so wlan0 never associates on a clean flash.
    # With iwd holding the passphrase it autoconnects on its own and NM reflects the connection (so
    # Steam still sees Wi-Fi through NM). This is the project's original proven iwd-direct credential.
    # NOTE: filename is <SSID>.psk for plain-ASCII SSIDs; iwd hex-encodes names containing
    # non-alphanumerics (e.g. spaces) as '=<hex>.psk' — not handled here (uncommon for test SSIDs).
    install -d -m 700 "${root}/var/lib/iwd"
    cat > "${root}/var/lib/iwd/${SD_WIFI_SSID}.psk" <<EOF
[Security]
Passphrase=${SD_WIFI_PSK}
EOF
    chmod 600 "${root}/var/lib/iwd/${SD_WIFI_SSID}.psk"
    [ -z "${SD_WIFI_COUNTRY}" ] && warn "SD_WIFI_COUNTRY unset — world regdom; 5 GHz won't associate"
  fi

  # enable services for interaction/verification with no keyboard:
  #   sshd + iwd (wifi) + systemd-resolved (DNS), diag (boot report).
  #   seatd: gamescope's DRM backend needs a seat (no logind seat over SSH).
  #   inputplumber: gamepad -> Steam Input (DualSense) mapping.
  #   NetworkManager (front-end Steam talks to) + iwd (its wifi backend) BOTH run now.
  #   pocknix-expand-root: first-boot grow of root partition+fs to fill the card.
  # NOTE: the USB-C network gadget (ssh over USB) is intentionally gone — it showed as a phantom
  # "wired" connection in Steam, and the port is dual-role (DTS data-role="dual"), so leaving it
  # free lets the USB-C port act as a host for peripherals (keyboard, storage, …).
  #   upower: battery %/time-to-empty for Steam's gamepadui (it reads battery only via the UPower
  #   D-Bus API) + Plasma. D-Bus-activated anyway, but enable it so it's up before Steam's first query.
  #   udisks2: Steam's Storage page enumerates FORMATTABLE external drives (the microSD "Format"
  #   flow) over the UDisks2 D-Bus API (CSystemStorageDeviceManagerLinux). It's D-Bus-activatable
  #   but Steam's storage manager enumerates once at startup and does not recover if UDisks2 comes
  #   up late, so a disabled udisks2 = empty format list even though the card is present. Enable it
  #   so it is running before Steam inits. (Mounted ext4 libraries still show via our automount; this
  #   is only the raw-drive/format list.) The UDisks2 polkit grant is in 50-pocknix-deck.rules.
  [ "${HOLODOR_RELEASE:-0}" = "1" ] || chroot "${root}" systemctl enable sshd
  #   pocknix-wifi-import: /flash/wifi.txt -> NM+iwd credentials before the network stack
  #   starts (keyboard-free Wi-Fi for the seedless first boot; ConditionPathExists-gated,
  #   so boots without the file skip it silently). Enabled on ALL images — it's just as
  #   useful for rescuing a dev image whose preseed went stale.
  chroot "${root}" systemctl enable iwd NetworkManager systemd-resolved seatd inputplumber \
        bluetooth upower udisks2 \
        pocknix-diag.service pocknix-expand-root.service \
        pocknix-lavd.service pocknix-gamescope-rt.service \
        pocknix-slot-successful.service pocknix-wifi-import.service \
        pocknix-charge-full.service pocknix-download-inhibit.service \
        >/dev/null 2>&1 || true
  # audio server (PipeWire) as per-user services — start in the autologin/session user.
  # WirePlumber applies the device UCM (shipped by the device BSP) automatically.
  # pocknix-proton-prep: watches for Steam downloading/updating Proton 11 ARM and keeps the compat
  # tool usable, so the first download needs no reboot (pocknix-steam also runs it at game start).
  chroot "${root}" systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service \
        pocknix-proton-prep.service \
        >/dev/null 2>&1 || true
  # Emulation first-login seeding: ~/ROMs tree + ES-DE/RetroArch/SRM configs (pocknix-emulation;
  # idempotent oneshot, never blocks the session).
  chroot "${root}" systemctl --global enable pocknix-roms-init.service >/dev/null 2>&1 || true
}

main() {
  ensure_kernel_in_rootfs
  # firmware is now installed into the rootfs by build-image.sh (make build)

  local root_mib img_mib boot_end
  root_mib=$(( $(du -sm "${ROOTFS_DIR}" | cut -f1) + SD_SLACK_MIB ))
  img_mib=$(( 1 + SD_BOOT_MIB + root_mib + 1 ))
  boot_end=$(( 1 + SD_BOOT_MIB ))
  log "creating ${OUT} (~${img_mib} MiB = ${SD_BOOT_MIB} boot + ${root_mib} root)"
  mkdir -p "${IMAGE_DIR}"
  rm -f "${OUT}"
  truncate -s "${img_mib}M" "${OUT}"

  log "partitioning (GPT: ${SD_BOOT_PARTNAME} fat32 + ${ROOT_LABEL} ext4)"
  parted -s "${OUT}" mklabel gpt
  parted -s "${OUT}" mkpart "${SD_BOOT_PARTNAME}" fat32 1MiB "${boot_end}MiB"
  parted -s "${OUT}" mkpart "${ROOT_LABEL}"        ext4  "${boot_end}MiB" 100%
  parted -s "${OUT}" set 1 legacy_boot on
  # Deterministic partition GUIDs (see SD_*_PARTUUID in config/pocknix.conf):
  # the arm-efi grub.cfg and the fstab below pin these, so an internal install's
  # identical POCKNIX_ROOT name/label can never steal the SD boot's root.
  sgdisk --partition-guid=1:"${SD_BOOT_PARTUUID}" \
         --partition-guid=2:"${SD_ROOT_PARTUUID}" "${OUT}" >/dev/null

  LOOP="$(losetup --show -fP "${OUT}")"
  log "loop: ${LOOP}"
  udevadm settle 2>/dev/null || sleep 1
  [ -e "${LOOP}p1" ] && [ -e "${LOOP}p2" ] || die "loop partitions ${LOOP}p1/p2 did not appear"

  mkfs.vfat -F 32 -n "${SD_FAT_LABEL}" "${LOOP}p1" >/dev/null
  mkfs.ext4 -F -q -L "${ROOT_LABEL}" "${LOOP}p2"

  MNT="$(mktemp -d)"
  # boot partition: KERNEL (+ md5); arm-efi additionally GRUB + dtbs + abl payload
  mount "${LOOP}p1" "${MNT}"
  cp "${KERNEL_IMG}" "${MNT}/KERNEL"
  ( cd "${MNT}" && md5sum KERNEL > KERNEL.md5 )
  [ "${BOOTLOADER}" = "arm-efi" ] && populate_arm_efi_boot "${MNT}"
  [ "${BOOTLOADER}" = "qcom-abl" ] && populate_qcom_abl_boot "${MNT}"
  sync; umount "${MNT}"
  # root partition: the rootfs
  mount "${LOOP}p2" "${MNT}"
  log "copying rootfs -> root partition (takes a bit)"
  # HOLODOR: leave the pacman package cache out of the shipped image. It carried 4.5 GiB
  # of already-installed packages (two 1 GiB fex-rootfs copies among them) and was most of
  # the 7.7 GiB compressed size (measured 2026-09-13: 3.2 GiB without it). Updates come
  # from the [pocknix] repo, not the cache; nothing on the device reads it.
  rsync -aHAX --numeric-ids --exclude='/var/cache/pacman/pkg/*' "${ROOTFS_DIR}/" "${MNT}/"
  firstboot_config "${MNT}"
  # Ownership gate: nothing outside /home should be owned by the host build user (uid/gid 1000 =
  # 'alarm' in the rootfs). A stray host-owned path here means a host->rootfs copy leaked ownership
  # (see the --chown=root:root rsyncs above) — which silently breaks privilege-bounded services like
  # systemd-timedated (couldn't write /etc/localtime -> timezone changes had no effect). Fail loudly.
  leaked="$(find "${MNT}" -xdev \( -uid 1000 -o -gid 1000 \) ! -path "${MNT}/home/*" -print -quit)"
  [ -z "${leaked}" ] || die "host-owned (uid/gid 1000) path leaked into the image: ${leaked#${MNT}} — a host->rootfs rsync needs --chown=root:root"
  sync; umount "${MNT}"; rmdir "${MNT}"; MNT=""
  losetup -d "${LOOP}"; LOOP=""
  trap - EXIT

  ok "SD image ready -> ${OUT}  ($(du -h "${OUT}" | cut -f1))"
  echo
  log "Flash it (DOUBLE-CHECK the device with lsblk first!):"
  echo "    sudo dd if=${OUT} of=/dev/sdX bs=4M conv=fsync status=progress"
  log "Then insert into the device (${DEVICE_PRETTY:-${DEVICE}}) and boot. root password: ${SD_ROOT_PASSWORD}"
  log "Internal ROCKNIX is untouched; remove the SD to boot it again."
}
main "$@"
