#!/usr/bin/env bash
# build-kernel.sh — build the linux-pocknix kernel for the selected device's SoC
# (kernel/${SOC}/, chosen by the device profile) and stage the boot artifact for
# the SoC's BOOTLOADER style: qcom-abl (mkbootimg Android boot image, sm8550) or
# arm-efi (raw Image loaded by GRUB, sm8250). Reproduces ROCKNIX's recipe
# (packages/linux/package.mk):
#
#   stock kernel.org linux-${KERNEL_VERSION}   (pinned in kernel/${SOC}/kernel.conf)
#     + patch stack in numeric subdir order: kernel/${SOC}/patches/*/
#     + the SoC tree's device trees (kernel/${SOC}/dts) with ensured Makefile entries
#     + the SoC config (kernel/${SOC}/config/linux.aarch64.conf)
#   -> make Image dtbs modules
#   -> boot image = gzip(Image) ++ appended DTBs, dummy ramdisk, mkbootimg (header v0)
#
# We boot a plain ext4 root with NO initramfs (UFS/SCSI/ext4 are built-in), so the
# cmdline uses a standard root= spec (KERNEL_CMDLINE) instead of ROCKNIX's
# LibreELEC boot=/disk=LABEL= convention, and the ramdisk stays a dummy.
#
# Outputs (per SoC):
#   build/kernel/<soc>/out/{Image,dtbs/,modroot/lib/modules/<ver>/,kernelrelease,soc}
#   build/image/<soc>/KERNEL   (qcom-abl: the boot image; arm-efi: the raw Image
#                               -> either way, deploy to /flash/KERNEL)

source "$(dirname "$0")/lib.sh"
need_linux
# pahole (pkg: dwarves) is required for CONFIG_DEBUG_INFO_BTF; without it olddefconfig
# silently drops BTF and the config gate dies late with a confusing message.
for t in curl tar xz gzip make gcc bc flex bison python3 git rsync patch pahole; do need_tool "$t"; done

KBUILD="${KERNEL_BUILD_DIR}"   # per-SoC: build/kernel/${SOC} (set in lib.sh)
KSRC="${KBUILD}/linux-${KERNEL_VERSION}"
JOBS="${JOBS:-$(nproc)}"
MKBOOTIMG=""

# native on aarch64, else require an aarch64 cross toolchain
if [ "$(uname -m)" = "aarch64" ]; then
  CROSS=""
else
  CROSS="${CROSS_COMPILE:-aarch64-linux-gnu-}"
  have "${CROSS}gcc" || die "cross-building on $(uname -m): need ${CROSS}gcc (or set CROSS_COMPILE)"
  log "cross-compiling with ${CROSS}"
fi
kmake() { make -C "${KSRC}" ARCH=arm64 ${CROSS:+CROSS_COMPILE=${CROSS}} "$@"; }

fetch_source() {
  mkdir -p "${CACHE_DIR}" "${KBUILD}"
  local tb="${CACHE_DIR}/linux-${KERNEL_VERSION}.tar.xz"
  if [ ! -f "${tb}" ]; then
    log "downloading kernel source: ${KERNEL_SOURCE_URL}"
    curl -fL --retry 3 -o "${tb}" "${KERNEL_SOURCE_URL}"
  else
    log "using cached kernel source: ${tb}"
  fi
  if [ -n "${KERNEL_SOURCE_SHA256}" ]; then
    echo "${KERNEL_SOURCE_SHA256}  ${tb}" | sha256sum -c - || die "kernel source sha256 mismatch"
    ok "kernel source checksum verified"
  else
    warn "KERNEL_SOURCE_SHA256 unset — build is NOT reproducible (pin it for releases)"
  fi
  log "extracting source -> ${KSRC}"
  rm -rf "${KSRC}"
  tar -C "${KBUILD}" -xf "${tb}"
}

# Optional series: a patches/<series>/ dir carrying a file named OPTIONAL is skipped
# unless its basename is listed in HOLODOR_KERNEL_EXTRA_SERIES (space-separated).
# Lets an experiment (e.g. 50-rotation-exp, DPU hardware rotation) live in-tree,
# numbered after 40-holodor, without touching the default build:
#   HOLODOR_KERNEL_EXTRA_SERIES="50-rotation-exp" make kernel
# A name listed but not present is a hard error (a typo must not silently build
# the default kernel and get deployed as the experiment).
series_is_selected() {
  local name="$1" s
  [ -f "${KERNEL_DIR}/patches/${name}/OPTIONAL" ] || return 0
  for s in ${HOLODOR_KERNEL_EXTRA_SERIES:-}; do
    [ "${s}" = "${name}" ] && return 0
  done
  return 1
}

apply_patches() {
  local d p n s
  for s in ${HOLODOR_KERNEL_EXTRA_SERIES:-}; do
    [ -d "${KERNEL_DIR}/patches/${s}" ] \
      || die "HOLODOR_KERNEL_EXTRA_SERIES names '${s}' but ${KERNEL_DIR}/patches/${s}/ does not exist"
    log "extra series selected: ${s}"
  done
  for d in "${KERNEL_DIR}"/patches/*/; do
    [ -d "${d}" ] || continue
    if ! series_is_selected "$(basename "${d}")"; then
      log "skipping optional series $(basename "${d}") (not in HOLODOR_KERNEL_EXTRA_SERIES)"
      continue
    fi
    n=0
    for p in "${d}"*.patch; do
      [ -f "${p}" ] || continue
      # patch(1) first; fall back to git apply for git-format diffs (renames,
      # new-file headers with modes) that patch(1) rejects — e.g. the armada-
      # sourced patches in 40-holodor.
      patch -p1 -d "${KSRC}" --dry-run -s -f < "${p}" >/dev/null 2>&1 \
        && patch -p1 -d "${KSRC}" -s -f < "${p}" >/dev/null \
        || (cd "${KSRC}" && git apply "${p}") \
        || die "patch failed to apply: ${p}"
      n=$((n+1))
    done
    log "applied $(basename "${d}"): ${n} patches"
  done
}

install_dts() {
  # Some SoC trees (sm8750) ship NO dts/ dir — their device trees arrive via the
  # patch stack (e.g. 0046/0047 add the CQ8725S/Odin3 sources + Makefile entries),
  # so there is nothing to overlay or register here.
  if [ ! -d "${KERNEL_DIR}/dts" ]; then
    log "no ${SOC} dts/ overlay — device trees come from the patch stack, skipping"
    return 0
  fi
  log "installing ${SOC} device trees + ensuring Makefile entries"
  rsync -a "${KERNEL_DIR}/dts/" "${KSRC}/arch/arm64/boot/dts/"
  # Register exactly the dts files the SoC tree ships (whatever their prefix —
  # the boot image carries ALL of them; the qcom ABL selects by board id, which
  # is what lets one SoC kernel package serve every device on that SoC).
  local mk="${KSRC}/arch/arm64/boot/dts/qcom/Makefile" dts name
  for dts in "${KERNEL_DIR}"/dts/qcom/*.dts; do
    [ -f "${dts}" ] || continue
    name="$(basename "${dts}" .dts)"
    if ! grep -q "${name}.dtb" "${mk}"; then
      echo "dtb-\$(CONFIG_ARCH_QCOM) += ${name}.dtb" >> "${mk}"
      log "  registered ${name}.dtb in qcom/Makefile"
    fi
  done
}

# Vendor downstream trace events (e.g. include/trace/events/qcom_haptics.h) still use the
# pre-6.10 two-argument __assign_str(dst, src); kernel 6.10+ made it one-arg (the src is now
# taken from the __string(dst, src) declaration). These never compiled while tracing was off,
# but enabling FTRACE/BPF_EVENTS (for scx_lavd, see configure()) turns TRACEPOINTS on, so every
# built driver's TRACE_EVENT expands for real and the stale ones break the build with
# "macro '__assign_str' passed 2 arguments, but takes just 1". Apply upstream's mechanical
# migration — drop the redundant 2nd arg — to every trace-event-defining header in the tree.
# Only stale two-arg call sites match; correct one-arg sites (no comma) and __assign_str_len
# are untouched. (__string itself is unchanged and stays two-arg.)
fixup_trace_events() {
  log "fixing stale two-arg __assign_str() in vendor trace events (post-6.10 one-arg API)"
  grep -rlZ --include='*.h' -e 'DECLARE_EVENT_CLASS' -e 'TRACE_EVENT' "${KSRC}" 2>/dev/null \
    | xargs -0 -r sed -i -E 's/__assign_str\(([^,()]+),[^()]*\)/__assign_str(\1)/g'
}

configure() {
  log "configuring kernel (.config from linux.aarch64.conf; no embedded initramfs)"
  sed -e "s|@DEVICENAME@|${DEVICE_HOSTNAME}|g" \
      -e 's|@INITRAMFS_SOURCE@||g' \
      "${KERNEL_DIR}/config/linux.aarch64.conf" > "${KSRC}/.config"

  # pocknix kernel config deltas (applied on top of the synced ROCKNIX config, so
  # they survive `make sync`):
  #  - zstd-compressed firmware loading (Arch ships firmware as .zst)
  #  - DRM_MSM built-in (=y, matching ROCKNIX). It was a MODULE to dodge an a740_sqe.fw
  #    "-2" at built-in probe (fw is on the not-yet-mounted root), BUT that made mdss+dpu+
  #    dsi+gpu all bind LATE (~4.1s) via one post-root udev modprobe, so the first DPU
  #    commit raced the panel's command-mode tearcheck into a PERSISTENT TE-dead latch
  #    (~10fps, "ctl start interrupt wait failed" / commit-done -22) that survived reboots
  #    (dummy panel regulators = the OS can't power-cycle the panel to reset it). =y makes
  #    msm probe EARLY during kernel init, off disp_cc's fresh power-on-reset PLL/RCG state,
  #    and bring the panel up clean — exactly ROCKNIX's bring-up. The "-2" is benign: the
  #    a6xx GPU is a separate platform device that -EPROBE_DEFERs on missing firmware, so the
  #    DISPLAY comes up regardless and the GPU retries once root mounts (ROCKNIX loads the fw
  #    at ~11.9s). VALIDATE on-device that GPU accel recovers; if it doesn't on our
  #    initramfs-less root, embed the fw via CONFIG_EXTRA_FIRMWARE rather than reverting to =m.
  #  - Android binder + binderfs for Waydroid: the synced config has
  #    ANDROID_BINDER_IPC off, so the Waydroid container can't start ("Failed to
  #    initialize Waydroid"). MEMFD_CREATE is already on, so modern Waydroid needs no
  #    ASHMEM. binderfs creates the binder/hwbinder/vndbinder devices dynamically.
  #  - USB/IP vhci-hcd: InputPlumber emulates the "Valve Steam Deck Controller"
  #    target as a virtual USB device via vhci-hcd; without it InputPlumber hides the
  #    physical gamepad but fails to create the virtual one, so Steam sees no controller
  #    ("modprobe: FATAL: Module vhci-hcd not found"). =m so InputPlumber modprobes it.
  #  - sched_ext (SCHED_CLASS_EXT) + BTF (DEBUG_INFO_BTF): the pluggable BPF scheduler
  #    class, so scx_lavd (the gaming/latency-aware, big.LITTLE-aware scheduler from the
  #    ALARM scx-scheds package, run --autopilot by pocknix-lavd.service) can load. BPF
  #    syscall/JIT are already on; a sched_ext program only attaches if the kernel exposes
  #    BTF at /sys/kernel/btf/vmlinux, which needs DEBUG_INFO_BTF=y AND pahole (dwarves)
  #    present in the build VM at compile time. The sm8550 base config sets
  #    DEBUG_INFO_REDUCED=y, which strips the type info BTF needs (BTF depends on
  #    !DEBUG_INFO_REDUCED) — so we turn REDUCED off too, else olddefconfig silently
  #    drops BTF *and* SCHED_CLASS_EXT (they vanish, with no "is not set" line).
  #    The sm8250 base config disables DEBUG_KERNEL entirely, which HIDES the whole
  #    debug-info choice from Kconfig: our DWARF selection gets dropped as invisible,
  #    the choice defaults to DEBUG_INFO_NONE, and BTF vanishes the same silent way
  #    (shipped once: lavd skipped on the RP5, session fell back to EEVDF,
  #    2026-07-13). Enable DEBUG_KERNEL (a visibility gate; sm8550 — our perf
  #    baseline — already ships =y) + force the choice off NONE onto
  #    DWARF_TOOLCHAIN_DEFAULT (both no-ops on sm8550). Both target symbols are
  #    covered by the post-olddefconfig assertions, which is how this was caught.
  #  - KALLSYMS_ALL: also DEBUG_KERNEL-gated, also missing from the sm8250 base
  #    config (sm8550 ships =y). scx_lavd's BPF resolves the per-cpu 'runqueues'
  #    ksym via kallsyms, and DATA symbols are only listed with _ALL — without it
  #    the prog load dies with "ldimm64 failed to find the address for kernel
  #    symbol 'runqueues'" (seen on the RP5 once BTF was fixed). Asserted below.
  #  - SCHED_CLUSTER: sm8550-baseline parity (cluster-aware scheduler topology;
  #    the 865 is 4xA77+4xA55 DynamIQ, same shape the option exists for).
  #  - tracing / BPF events (FTRACE, KPROBES, KPROBE_EVENTS, PERF_EVENTS -> BPF_EVENTS):
  #    scx_lavd's BPF objects call bpf_trace_printk and attach futex/execve tracepoints.
  #    The ROCKNIX config ships FTRACE off, so bpf_trace_printk's helper proto is absent
  #    and the verifier rejects the whole scheduler ("program of this type cannot use
  #    helper bpf_trace_printk", BPF load -EINVAL -> scx_lavd crash-loops). BPF_EVENTS is
  #    def_bool y once (KPROBE_EVENTS||UPROBE_EVENTS) + PERF_EVENTS are on, which need the
  #    tracing core (FTRACE) + KPROBES.
  #  - FUNCTION_TRACER + DYNAMIC_FTRACE (-> WITH_CALL_OPS/WITH_DIRECT_CALLS on arm64):
  #    scx-scheds >= 1.1 attaches fentry programs (scx_lib_init_probe), which need the BPF
  #    trampoline; on arm64 that requires dynamic-ftrace direct calls. Without it the attach
  #    fails -ENOTSUPP (error 524), scx_lavd exits, systemd hits the start limit, and the
  #    session falls back to EEVDF, where Steam's nice-19 main thread starves (sub-10fps UI,
  #    low clocks). KPROBES alone was enough for scx 1.0.x; the rolling ALARM package moved.
  #    DYNAMIC_FTRACE patches call sites to NOPs at boot, so runtime overhead when not
  #    tracing is ~zero. The WITH_CALL_OPS/WITH_DIRECT_CALLS variants are not directly
  #    selectable; they follow from these two via olddefconfig (verified in the built
  #    .config by the assertion below).
  #  - default cpufreq governor performance -> schedutil: LAVD does its own per-core DVFS
  #    via scx_bpf_cpuperf_set(), which only takes effect under schedutil (the one governor
  #    that honours scheduler frequency hints). Under performance, clocks pin to max and
  #    LAVD's frequency intelligence — and the handheld's thermal headroom — is lost. Still
  #    runtime-overridable (echo performance > .../cpufreq/policy*/scaling_governor) to A/B.
  #  - MMC_SDHCI_MSM_DOWNSTREAM: the Qualcomm downstream sdhci-msm driver (patches
  #    0210-0212, from armbian PR #9546). The RP6 + Odin 2 family dts rebind sdhc_2 (microSD) to it
  #    ("qcom,sdhci-msm-v5-downstream") for UHS-I SDR104 (~85MB/s vs ~13MB/s): the
  #    upstream driver has an SDR104 tuning/clock regression on sm8550, which is why
  #    the vendor DTs cap the slot to legacy High-Speed. =y like MMC_SDHCI_MSM (which
  #    stays on; distinct compatibles + driver names, no conflict).
  #  - QCOM_Q6V5_PAS as MODULE: the synced sm8250 config has it =y (built-in), so the
#    adsp/cdsp/slpi remoteprocs probe at ~1s — before our initramfs-less root (and thus
#    /usr/lib/firmware) exists — and remoteproc does NOT retry a failed request_firmware:
#    the DSPs sit offline forever and the q6 sound card never assembles ("no soundcards",
#    RP5 bring-up 2026-07-13; LPASS pinctrl also fails its clocks without the ADSP).
#    =m loads post-root exactly like the sm8550 config already ships (=m there, which is
#    why RP6 audio never hit this), the firmware is present, the ADSP authenticates and
#    boots, and LPASS/soundwire/codecs cascade in (verified live via manual rebind).
#    No-op on sm8550. (cdsp still fails PAS auth -22 on the RP5 with linux-firmware's
#    blob — harmless, nothing uses it; same on ROCKNIX.)
#  - UNICODE (UTF-8 normalization + casefolding tables): the ROCKNIX config ships this off.
  #    SteamOS formats every SD card with the ext4 `casefold` feature (case-insensitive dir
  #    lookups, so mixed-case Windows/Proton game paths resolve). ext4 REFUSES to mount a
  #    casefold filesystem without CONFIG_UNICODE ("Filesystem with casefold feature cannot be
  #    mounted without CONFIG_UNICODE") — so a card formatted on another Steam Deck won't mount
  #    here at all, and Steam never sees it. =y builds the UTF-8 normalization table in (no
  #    module: filesystems may be mounted before modules load). Pairs with the SD automount
  #    stack (pocknix-sdcard-automount) that mounts + registers the card with Steam.
  "${KSRC}/scripts/config" --file "${KSRC}/.config" \
    --module QCOM_Q6V5_PAS \
    --enable UNICODE \
    --enable MMC_SDHCI_MSM_DOWNSTREAM \
    --enable FW_LOADER_COMPRESS \
    --enable FW_LOADER_COMPRESS_ZSTD \
    --enable ANDROID \
    --enable ANDROID_BINDER_IPC \
    --enable ANDROID_BINDERFS \
    --set-str ANDROID_BINDER_DEVICES "binder,hwbinder,vndbinder" \
    --module USBIP_CORE \
    --module USBIP_VHCI_HCD \
    --enable DEBUG_KERNEL \
    --enable KALLSYMS_ALL \
    --enable SCHED_CLUSTER \
    --disable DEBUG_INFO_NONE \
    --enable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
    --disable DEBUG_INFO_REDUCED \
    --enable DEBUG_INFO_BTF \
    --enable SCHED_CLASS_EXT \
    --enable FTRACE \
    --enable FUNCTION_TRACER \
    --enable DYNAMIC_FTRACE \
    --enable KPROBES \
    --enable KPROBE_EVENTS \
    --enable UPROBE_EVENTS \
    --enable PERF_EVENTS \
    --enable BPF_EVENTS \
    --disable CPU_FREQ_DEFAULT_GOV_PERFORMANCE \
    --enable CPU_FREQ_DEFAULT_GOV_SCHEDUTIL

  # sm8250-only: the LPASS macro codecs as MODULES (=y in the synced config; the
  # symbols are unset on sm8550, so this must not run there — --module would turn
  # them ON). Same disease as Q6V5_PAS one layer down: the q6 audio clocks these
  # drivers enable come from ADSP services that settle asynchronously AFTER the
  # remoteproc reports "up", so any macro probing inside the window hard-fails
  # -ETIMEDOUT and the kernel never retries a failed probe (va_macro at 9.7s with
  # the adsp up at 6.7s, RP5 2026-07-13; a different driver loses the race each
  # boot). Built-in they are unhealable (no bind attrs); as modules the BSP's
  # pocknix-sm8250-audio-heal service reloads whichever ones lost the race until
  # the sound card assembles.
  if [ "${SOC}" = "sm8250" ]; then
    "${KSRC}/scripts/config" --file "${KSRC}/.config" \
      --module SND_SOC_LPASS_WSA_MACRO \
      --module SND_SOC_LPASS_VA_MACRO \
      --module SND_SOC_LPASS_RX_MACRO \
      --module SND_SOC_LPASS_TX_MACRO
  fi

  # Optional patch series (HOLODOR_KERNEL_EXTRA_SERIES, see apply_patches) stamp the kernel
  # release: `uname -r` reads e.g. 7.1.3-50-rotation-exp, the modules land in their own
  # /usr/lib/modules/<release> dir, and the experimental kernel can never be mistaken for the
  # shipped one on a device or in a log. The default build keeps the synced CONFIG_LOCALVERSION.
  if [ -n "${HOLODOR_KERNEL_EXTRA_SERIES:-}" ]; then
    local lv; lv="-$(printf '%s' "${HOLODOR_KERNEL_EXTRA_SERIES}" | tr -s ' ' '-')"
    "${KSRC}/scripts/config" --file "${KSRC}/.config" --set-str LOCALVERSION "${lv}"
    log "kernel release stamped with extra series: LOCALVERSION=${lv}"
  fi

  # olddefconfig auto-accepts defaults for any new symbols (no prompts, no stdin).
  # NB: do NOT pipe `yes` into it — `yes` would take SIGPIPE and, under pipefail,
  # abort the script with exit 141.
  kmake olddefconfig >/dev/null

  # Assert the whole scx_lavd chain actually resolved: the fentry/BPF-trampoline
  # symbols (attach fails ENOTSUPP without them) AND BTF + sched_ext themselves —
  # olddefconfig silently drops any of these when a dependency is missing (bitten
  # twice: REDUCED on sm8550, DEBUG_INFO_NONE on sm8250), and the failure only
  # shows up on-device as pocknix-lavd's ConditionPathExists quietly skipping.
  local sym
  for sym in FUNCTION_TRACER DYNAMIC_FTRACE DYNAMIC_FTRACE_WITH_DIRECT_CALLS \
             DEBUG_INFO_BTF SCHED_CLASS_EXT KALLSYMS_ALL; do
    grep -q "^CONFIG_${sym}=y" "${KSRC}/.config" \
      || die "kernel config: CONFIG_${sym} did not resolve to =y (scx_lavd would not run — check the dependency olddefconfig dropped it for)"
  done
}

build_kernel() {
  log "building Image + dtbs + modules (-j${JOBS}) — this takes a while"
  kmake -j"${JOBS}" Image dtbs modules
}

stage() {
  log "staging artifacts -> ${KBUILD}/out"
  rm -rf "${KBUILD}/out"
  mkdir -p "${KBUILD}/out/dtbs"
  cp "${KSRC}/arch/arm64/boot/Image" "${KBUILD}/out/Image"
  find "${KSRC}/arch/arm64/boot/dts" -name '*.dtb' -exec cp {} "${KBUILD}/out/dtbs/" \;
  kmake INSTALL_MOD_PATH="${KBUILD}/out/modroot" modules_install >/dev/null
  rm -f "${KBUILD}/out/modroot"/lib/modules/*/build "${KBUILD}/out/modroot"/lib/modules/*/source
  kmake -s kernelrelease > "${KBUILD}/out/kernelrelease"
  ok "kernel $(cat "${KBUILD}/out/kernelrelease") staged ($(ls "${KBUILD}/out/dtbs" | wc -l | tr -d ' ') dtbs)"
}

fetch_mkbootimg() {
  MKBOOTIMG="${KBUILD}/mkbootimg/mkbootimg.py"
  [ -f "${MKBOOTIMG}" ] && return 0
  log "fetching mkbootimg (${MKBOOTIMG_COMMIT:0:12})"
  rm -rf "${KBUILD}/mkbootimg-src"
  git clone -q "${MKBOOTIMG_URL}" "${KBUILD}/mkbootimg-src" || die "mkbootimg clone failed"
  git -C "${KBUILD}/mkbootimg-src" checkout -q "${MKBOOTIMG_COMMIT}" \
    || warn "mkbootimg: pinned commit unavailable, using clone HEAD"
  mkdir -p "${KBUILD}/mkbootimg"
  cp -r "${KBUILD}/mkbootimg-src/gki" "${KBUILD}/mkbootimg-src/mkbootimg.py" "${KBUILD}/mkbootimg/"
}

# Assemble the qcom-abl boot image. $1 = optional ramdisk path; default is a dummy
# (we have no initramfs). gzip(Image) with all DTBs appended is the "kernel".
assemble_bootimg() {
  fetch_mkbootimg
  mkdir -p "${IMAGE_DIR}"
  local kgz="${KBUILD}/out/kernel.gz" ramdisk="${1:-}" d
  gzip -c "${KBUILD}/out/Image" > "${kgz}"
  for d in "${KBUILD}"/out/dtbs/*.dtb; do [ -f "${d}" ] && cat "${d}" >> "${kgz}"; done
  if [ -z "${ramdisk}" ]; then
    local fwlist="${POCKNIX_ROOT}/kernel/${SOC}/config/bootimg-firmware.list"
    if [ -f "${fwlist}" ]; then
      # Boot-critical firmware initramfs. The msm/adreno driver is BUILT-IN and
      # requests its SQE microcode BEFORE the SD rootfs is mounted; with no
      # initramfs that request ENOENTs, the GPU never initializes, and gamescope
      # exits immediately. Whether the probe beats the mount is timing luck —
      # v0.2 lost the race on hardware, the hand-built v0.1 card happened to win
      # it. The kernel serves early request_firmware() from the unpacked
      # initramfs, so embed the listed files (~130KB): from the built rootfs when
      # present, else fetched from upstream linux-firmware (same source
      # build-image reconciles the rootfs against).
      local fwroot="${KBUILD}/out/bootimg-fw" f
      rm -rf "${fwroot}"; mkdir -p "${fwroot}/lib/firmware"
      while IFS= read -r f || [ -n "$f" ]; do
        f="$(echo "$f" | tr -d '[:space:]')"; [ -z "$f" ] && continue
        mkdir -p "${fwroot}/lib/firmware/$(dirname "${f}")"
        if [ -e "${ROOTFS_DIR}/usr/lib/firmware/${f}" ]; then
          cp "${ROOTFS_DIR}/usr/lib/firmware/${f}" "${fwroot}/lib/firmware/${f}"
        elif ! curl -fsSL --retry 3 --max-time 120 -o "${fwroot}/lib/firmware/${f}" \
               "https://web.git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/${f}"; then
          die "bootimg firmware ${f}: not in rootfs and unfetchable — without it the GPU cannot init (see bootimg-firmware.list)"
        fi
      done < "${fwlist}"
      ramdisk="${KBUILD}/out/ramdisk.fw"
      if have cpio; then
        (cd "${fwroot}" && find lib | cpio -o -H newc --quiet) | gzip -9 > "${ramdisk}"
      else
        (cd "${fwroot}" && bsdtar --format newc -cf - lib) | gzip -9 > "${ramdisk}"
      fi
      log "bootimg: embedded boot-critical firmware initramfs ($(du -h "${ramdisk}" | cut -f1))"
    else
      # No boot-critical firmware for this SoC. Ship a VALID empty cpio so the
      # kernel unpacks it cleanly instead of printing "Initramfs unpacking
      # failed" (harmless, but noisy). Falls back to a dummy string if cpio is absent.
      ramdisk="${KBUILD}/out/ramdisk.empty"
      if have cpio; then
        printf '' | cpio -o -H newc --quiet > "${ramdisk}" 2>/dev/null
      else
        printf 'dummy' > "${ramdisk}"
      fi
    fi
  fi
  log "assembling qcom-abl boot image -> ${IMAGE_DIR}/KERNEL"
  python3 "${MKBOOTIMG}" \
    --kernel "${kgz}" --ramdisk "${ramdisk}" \
    --kernel_offset 0x00000000 --ramdisk_offset 0x00000000 --tags_offset 0x00000000 \
    --os_version 12.0.0 --os_patch_level "$(date '+%Y-%m')" --header_version 0 \
    --cmdline "${KERNEL_CMDLINE}" \
    -o "${IMAGE_DIR}/KERNEL" || die "mkbootimg failed"
  ok "boot image ready -> ${IMAGE_DIR}/KERNEL"
  log "cmdline: ${KERNEL_CMDLINE}"
}

main() {
  fetch_source
  apply_patches
  install_dts
  fixup_trace_events
  configure
  build_kernel
  stage
  case "${BOOTLOADER}" in
    arm-efi)
      # ROCKNIX arm-efi contract (SM8250): the ABL chainloads GRUB, whose
      # "linux /KERNEL" line loads a RAW arm64 Image. The dtb is a separate
      # "devicetree /boot/grub/<board>.dtb" file and the cmdline lives in
      # grub.cfg (shipped by pocknix-bootloader-<soc>). No Android boot image,
      # no mkbootimg, no appended dtbs.
      mkdir -p "${IMAGE_DIR}"
      cp "${KBUILD}/out/Image" "${IMAGE_DIR}/KERNEL"
      ok "raw Image staged -> ${IMAGE_DIR}/KERNEL (arm-efi: cmdline + dtb come from GRUB)"
      ;;
    *)
      assemble_bootimg "$@"
      # Stage the on-device boot-image rebuild inputs into out/ for the linux-pocknix-<soc>
      # package: the mkbootimg tool, so the package's alpm hook can rebuild /flash/KERNEL on the
      # device exactly the way this build does. (The cmdline the hook reads is shipped by the
      # device BSP; out/cmdline is kept as a build record of what the boot image was given.)
      rm -rf "${KBUILD}/out/mkbootimg"
      cp -r "${KBUILD}/mkbootimg" "${KBUILD}/out/mkbootimg"
      ;;
  esac
  printf '%s' "${KERNEL_CMDLINE}" > "${KBUILD}/out/cmdline"
  # SoC marker: records which SoC produced out/. Kernel outputs live in
  # per-SoC dirs now, so the downstream marker checks are insurance against
  # manual copies/renames rather than a shared-dir necessity.
  printf '%s' "${SOC}" > "${KBUILD}/out/soc"
  ok "${KERNEL_PKG} build complete"
}
main "$@"
