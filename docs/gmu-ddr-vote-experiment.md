# DDR bandwidth votes / GMU (the "7.1.3 vs 7.1.5" item) — scoped 2026-08-16

Verdict up front: **NO-GO as framed. The experiment doesn't exist.** There is no
alternative GMU firmware to swap, and the 7.1.3→7.1.5 kernel delta contains zero
bandwidth-vote changes. Our 7.1.3 tree already implements DDR voting identically to
current upstream master. Details, receipts, and the one remaining (low-value) knob below.

## 1. What the device runs today (verified live 2026-08-16)

- GMU firmware: `qcom/gen80000_gmu.bin`, kernel logs **"Loaded GMU firmware v5.1.25"**
  (journal, boot of Aug 15). Also loads `gen80000_sqe.fw` and `gen80000_aqe.fw`;
  zap shader `qcom/sm8750/gen80000_zap.mbn`.
- The on-device copy (`/lib/firmware/qcom/gen80000_gmu.bin`, md5
  `1f48c67a7f979a7c8607e00d39320fd2`) is **byte-identical to upstream linux-firmware
  `main`** (fetched and md5-compared).
- The same three files are ALSO embedded in the boot image's tiny firmware initramfs
  (`kernel/sm8750/config/bootimg-firmware.list` → `scripts/build-kernel.sh
  assemble_bootimg`), because the built-in adreno driver races the SD/UFS rootfs mount.
  **Early probe is served from the initramfs copy — a rootfs-only firmware swap would
  not reliably take effect.** Any firmware change means rebuilding `/flash/KERNEL`.
- Driver request path: catalog entry for chip id `0x44050000` (A830, `ADRENO_8XX_GEN1`)
  in `drivers/gpu/drm/msm/adreno/a6xx_catalog.c` names exactly these files. Nothing else
  is ever requested.

## 2. Alternative GMU firmware: none exists

- linux-firmware history for `qcom/gen80000_gmu.bin`: **one commit ever**
  ("qcom: Add firmwares for sm8750 GPU", 2025-12-11). No older or newer build has ever
  been published. Same story for sqe/aqe.
- The Android dump (`odin3-firmware-20251206/`, still a sealed 1.8 GB 7z) would contain
  AYN's KGSL-stack GMU firmware, but that pairs with Qualcomm's downstream KGSL driver
  and its own HFI protocol expectations. Feeding it to the mainline msm driver is
  unsupported and not a meaningful experiment — the mainline driver + v5.1.25 is the
  only validated pair.
- So the "firmware-file swap" version of this experiment is **not possible**: there is
  nothing to swap to.

## 3. "7.1.3 vs 7.1.5": the kernel delta is empty where it matters

The review item's real meaning is the ROCKNIX kernel snapshot version (our tree =
stock kernel.org 7.1.3 + ROCKNIX patch stack; `kernel/sm8750/kernel.conf`). Checked
both sides:

- **Stock stable 7.1.3 → 7.1.5** (full ChangeLogs from cdn.kernel.org, grepped): the
  complete drm/msm + qcom-dts delta is:
  - `drm/msm/a8xx: Fix RSCC offset` (correctness fix to GMU RSCC register base)
  - `drm/msm/a8xx: Make a8xx_recover IFPC safe` (crash-recovery robustness)
  - dp/mdss fixes (ISR enums, HPD bit, UBWC programming)
  - `arm64: dts: qcom: sm8750:` ICE node + DSI1 phy ref clock — no GPU/opp/interconnect
    changes.
  **Zero bandwidth-vote, interconnect, GMU-vote, or OPP changes.**
- **ROCKNIX `next` still pins SM8750 = 7.1.3** (checked
  `projects/ROCKNIX/packages/linux/package.mk` on GitHub 2026-08-16). There is no
  ROCKNIX 7.1.5 SM8750 tree to A/B against. Armada's newer base is the only other
  comparator, and since the stock delta is nil, any difference would have to be an
  Armada-private patch — none is known, and their fps edge is already explained as
  probable frame-gen (see cyberpunk-bench-plan.md).

## 4. Our 7.1.3 tree already votes DDR the modern way (== upstream master)

Read in `build/kernel/sm8750/linux-7.1.3/drivers/gpu/drm/msm/adreno/`:

- Catalog A830 entry has the BCM table: `SH0` (buswidth 16), `MC0` (buswidth 4), `ACV`
  (fixed, perfmode BIT(2), threshold 8,171,875 kBps).
- DT (`arch/arm64/boot/dts/qcom/sm8750.dtsi`, from ROCKNIX patch 0038): GPU node has
  `interconnects = <&gem_noc MASTER_GFX3D ... &mc_virt SLAVE_EBI1 ...>` and per-OPP
  `opp-peak-kBps` — **20,832,031 kBps (~20.8 GB/s) at 1050/1100 MHz**, stepping down to
  2,136,718 at 222 MHz.
- `a6xx_gmu_build_bw_table` + `a6xx_gmu_rpmh_bw_votes_init` build per-level BCM TCS
  votes from cmd-db; `a6xx_hfi_send_bw_table` takes the dynamic
  `a6xx_generate_bw_table` path (bcms present, nr_gpu_bws > 1); `a6xx_gmu_set_freq`
  sends perf index + bw index over HFI so the **GMU votes DDR directly to RPMh through
  its own RSC on every DCVS change**. That's why `interconnect_summary` shows the GPU
  row at 0/0 — expected, not a bug.
- Diffed against torvalds/master `a6xx_gmu.c` (fetched 2026-08-16): behavior is
  identical, **including** the one asymmetry: the 25% AB (average-bandwidth) vote is
  gated `adreno_is_a750_family()` — A7xx GEN3 only. A8xx gets IB-only votes **upstream
  too**. Our snapshot is not behind; there is no bw-vote code to port.

## 5. Is DDR bandwidth even the limiter? No evidence for it

- There is no DDR/memlat devfreq on this kernel (`/sys/class/devfreq/` = ufs + gpu
  only); DDR floor from the CPU side comes from the dcvs PMUs (icc summary showed
  ~6.2 GB/s peak there), and the GPU's 20.8 GB/s vote rides on top via the GMU at the
  pinned 1100 MHz OPP.
- The established Cyberpunk diagnosis (cyberpunk-bench-plan.md) is **present-path
  wait-bound**: GPU ~52% busy, frametime floored at ~48 ms while the GPU is already at
  its top OPP — i.e. the GPU is stalling on presentation, not on memory. A DDR
  bandwidth increase cannot move a wait-bound ceiling.
- Side observation from the live dmesg (unrelated to DDR, but flagging it): the running
  game is streaming `gpu fault ... type=TRANSLATION source=UCHE` at iova
  `0x167a8e000/040`. That's a page-fault storm, not a bandwidth symptom — worth its own
  investigation someday (and note 7.1.5's two a8xx stability fixes above would be the
  bump-era pickups).

## 6. The one concrete knob left (if we ever want it): AB votes on A8xx

A one-line kernel patch, documented here so the option isn't lost — **not recommended
now** (expected gain ~0 while wait-bound; GMU v5.1.25 gen8 support for AB bits is
unproven — upstream deliberately hasn't enabled it):

```c
/* a6xx_gmu.c, a6xx_gmu_set_freq(), ~line 186 */
-		if (bw && adreno_is_a750_family(adreno_gpu)) {
+		if (bw && (adreno_is_a750_family(adreno_gpu) ||
+			   adreno_is_a8xx(adreno_gpu))) {
```

Procedure if ever run: add as `kernel/sm8750/patches/40-holodor/00xx-a8xx-ab-votes.patch`,
`make kernel` + rebuild `linux-pocknix-sm8750` (bump pkgrel), keep the previous
`.pkg.tar` for rollback, `pacman -U` on device (alpm hook rebuilds `/flash/KERNEL`),
reboot. 2 reboots per A/B leg. Failure mode: worst case the GMU NACKs HFI DCVS or the
GPU wedges → device still boots (GPU init failure does not block boot; you get the
no-gamescope fallback + ssh), revert = `pacman -U` the previous kernel package + reboot.
Not a brick risk as long as the known-good kernel `.pkg.tar` is kept on-device first.

## 7. GO/NO-GO

**NO-GO.** Reasoning:
1. No alternative GMU firmware exists (single upstream release, device copy identical).
2. The 7.1.3→7.1.5 delta contains no DDR/bandwidth/GMU-vote changes, and ROCKNIX
   hasn't even bumped SM8750 past 7.1.3 — there is no other tree to A/B.
3. Our kernel's DDR voting already matches upstream master exactly; the GMU votes the
   full ~20.8 GB/s tier at the pinned top OPP.
4. The workload is present-path wait-bound at 52% GPU busy — more DDR bandwidth cannot
   raise a ceiling the GPU isn't hitting.

Retire item (5) from the 2026-08-14 squeeze list. The kernel-bump-to-7.1.5 idea stays
alive for OTHER reasons (a8xx RSCC/IFPC stability fixes, haptics-era patches), just not
for fps. The fps effort should go to the untried levers that still exist: the bench
matrix itself, scx_lavd A/B, and frame-gen.
