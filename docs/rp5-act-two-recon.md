# Holodor Act Two recon: Retroid Pocket 5 (SM8250 / Adreno 650)

Research sweep run 2026-08-31 (agent; sources cited inline). Read alongside
docs/ROADMAP.md — Act Two starts after the Odin 3 release train.

## Headline: the RP5 port already exists inside Holodor's own fork

The fork already contains a complete, upstream-hardware-validated sm8250/RP5
device family — `kernel/sm8250/` and `devices/sm8250/` — authored by shuuri-labs
(upstream pocknix-os) and inherited at fork time. All 16 commits touching those
paths are shuuri-labs', latest `74eff16` (2026-07-23). Upstream validated on a
real RP5: `devices/sm8250/packages/pocknix-bsp-sm8250/boards/rp5.conf` cites
on-device validation 2026-07-13 and an internal-storage recon 2026-07-16; commit
`c2865b8` is "install: arm-efi internal install for the RP5". It has never been
built on fusor (`build/` holds only sm8550/sm8750 trees). Holodor's post-fork
work (Holo Core base, seedless bootstrap, own signing, mesa-next) is harness-
level, above the device boundary in `devices/README.md`.

**Act Two is therefore not a port: it is "build `DEVICE=sm8250`, cherry-pick
~5 upstream fixes, validate on hardware, reconcile Holo Core deltas."**

What the inherited family includes: kernel 7.1.2 (stock kernel.org + 35
ROCKNIX-derived patches), DTS for six boards incl.
`sm8250-retroidpocket-rp5.dts`, the family BSP (runtime board select by DT
model, audio heal/resume services, UCM, udev, InputPlumber
`01-retroid-controller.yaml`/`rp5-gamepad.yaml`), the arm-efi GRUB bootloader
package (`packages/pocknix-bootloader-sm8250/`, vendored ROCKNIX
`bootaa64.efi`), and the metapackage. Boards wired: RP5, Flip 2 (Flip 2
explicitly hardware-unverified).

Panel caveat: NOT native landscape — CH13726A AMOLED, native 1080x1920
portrait, mounted `rotation = <270>`, same gamescope `--force-orientation left`
transpose contract as the RP6, already encoded in `boards/rp5.conf` (incl. the
deliberate fake 177x100mm output size for Steam UI scale).

## 1. Upstream pocknix-os state

Default branch `main`, HEAD `9a7a6a1` (2026-08-27), v0.3.0 tagged `70c1340`
(08-14). Upstream userland is Arch Linux ARM, not Holo Core — Holo Core is
Holodor's own axis of divergence.

The restructure landed in two waves post-fork: 08-10..13 (frozen
`[pocknix-base]` ALARM snapshot, locked/rolling modes — `be1a72b`, `82b2b54`)
and 08-20 (shared/soc split — `73e0566` splits `packages/` into
`packages/shared/` → `[pocknix-shared]` and `packages/soc/` per-SoC localrepos
gated by one-line `socs` files; `414b56e` metapackages; `ff95b07` retires most
`config/packages/*.list`; pacman order [pocknix] → [pocknix-shared] →
[pocknix-base]). A new SoC needs the same eight artifacts as before — only the
package dir locations moved.

**sm8250 upstream changes since fork (cherry-pick shopping list):**
- `82fbb2e` (08-25) kernel bump to 7.2 + ROCKNIX next resync (36/36 patches
  apply with fuzz only)
- `8755514` (08-25) **`gpt` added to kernel cmdline** — Retroid recovery images
  leave the internal UFS primary GPT corrupt; without `gpt` the ABL partitions
  are invisible
- `d3b4743` (08-17) + `a8b8635` (08-03) **DXVK-2 for a6xx**: a650 lacks 8-bit
  storage so DXVK 3 rejects the GPU; upstream ships dxvk2-pinned GE/Cachy
  protons + `pocknix-dxvk2-donor` (pacman hook swapping DXVK 2.7 into
  downloaded Valve ARM Protons)
- `fb6c759` (08-14) sm8250-only desktop-mode gamepad calibration (GPcal,
  RP5-verified)
- `57430c7` (08-03) ROCKNIX resync (gpu-tuning patch replaces gpu-opp-table)
- `957cdf0` (08-20) ESP-types the boot FAT in the internal installer

Upstream has no sm8750 of its own (Odin 3 = "Planned"). Restructure-vs-fork
verdict: rebasing buys nothing for the RP5 — device content identical either
side of the split, and upstream's base is ALARM. The restructure merge stays
parked (HANDOFF 08-24 block), orthogonal.

## 2. ROCKNIX RP5 support

Device dir `projects/ROCKNIX/devices/SM8250/` (local checkout `b895b27`
08-01 pins kernel 7.1.2; upstream bumped to 7.2 in `92020087` 08-19). Six
boards share the family. RP5 DTB `sm8250-retroidpocket-rp5.dtb`, compatible
`"retroidpocket,rp5"`. 28 device patches. Everything works per the ROCKNIX
wiki matrix (rocknix.org/devices/retroid/retroid-pocket-5/):

- **Wifi/BT**: QCA6390 — wifi over PCIe via ath11k, BT on uart6 (hci_uart/QCA)
- **Audio**: LPASS/Q6 ADSP path; WCD9385 headphone codec (SoundWire), WSA881x
  amps; quirks: `99-wcd938x-nosleep.rules` for jack detect, PipeWire quantum
  re-kick after wake, audio-as-modules since 7.2 (`c50963e3`, va_macro-vs-ADSP
  boot race)
- **Panel**: vendored CH13726A DRM driver (0058) + RP5 smooth-brightness fix
  (0016)
- **Touchscreen**: FocalTech FT5452 on i2c13 (edt-ft5x06)
- **Controller**: MCU on uart16, serdev driver `retroid.c` (0008), VID
  0x2020/PID 0x3001; rumble 0013 + qcom-spmi-haptics 0009; stick RGB = two
  HTR3212 I2C controllers (0010)
- **Charging**: PM8150B SMB charger (0011) + fuel gauge
- **Suspend**: s2idle, enabled and relied on; sleep.d hooks turn LEDs off
  pre-sleep and restore/re-kick audio post-wake; no mem_sleep_default override
- Misc: stable wifi/BT MACs from SoC serial (0014), pwm-fan, GPU OPP/overclock,
  USB-C DP-altmode dual-screen

## 3. Boot path — much friendlier than the Odin

- **No unlock, no ABL flash for SD boot.** ROCKNIX SM8250 uses
  `BOOTLOADER="arm-efi"`: the STOCK boot chain loads GRUB
  `EFI/BOOT/bootaa64.efi` off the SD FAT → raw Image + per-board DTB, no
  initramfs. Upstream dropped the ROCKNIX ABL payload from the sm8250 SD as
  "neither required nor recommended" (`116adeb`, 07-17). No fastboot unlock in
  any guide.
- Mechanism (medium confidence): RP5 is dual-boot-capable from the factory —
  U-Boot on a dedicated `loader` partition provides the UEFI environment,
  source published by Retroid (github.com/RetroidPocket/u-boot; confirmed by
  Armbian PR armbian/build#7521). Vol+ at boot = boot menu; autoboot-to-SD
  settable. The optional ROCKNIX ABL (v1.1.7) exists for internal-install
  direct-boot, flashed from rooted Android with backup/restore pair — SD boot
  never touches it.
- **Internal install**: `boards/rp5.conf` recon — main LUN /dev/sda (KIOXIA
  UFS, 4K sectors), Android GPT with userdata LAST → the Odin-proven
  shrink-and-append flow applies unchanged; boot chain lives on a separate LUN
  (/dev/sde), never touched. ROCKNIX installtointernal supports SM8250.
- **Rescue**: EDL (9008) reachable by button combo, no test point; community
  stock-firmware QFIL packages exist
  (github.com/TheGammaSqueeze/Retroid_Pocket_Stock_Firmware); Retroid publishes
  recovery images (wart: they corrupt the primary GPT — hence the `gpt`
  cmdline fix). Only soft-brick reports found, all EDL-recoverable. No AVB
  partial-flash trap analogue on the SD path.

## 4. Graphics: a650 is the easy case

- a650 = first-class mature turnip target: Vulkan 1.3 across a6xx, turnip
  default-enabled aarch64 Vulkan driver since Mesa 25.1. Roughly five years
  ahead of a830 in maturity.
- Stock Holo Core mesa 25.2.7 would very likely drive a650 fine — moot anyway:
  Holodor ships mesa-next 26.3.0-devel + vulkan-freedreno-next for every
  device. One data point against old pins: upstream moved off ROCKNIX 25.1.5
  because that turnip GPU-faults under Eden/Switch.
- **The real graphics work item is DXVK, not mesa**: a6xx lacks 8-bit storage,
  DXVK 3 rejects the GPU. Upstream's dxvk2-donor mechanism must be
  ported/adapted to Holodor's seedless Valve-Proton bootstrap.

## 5. Firmware: all upstream, zero extra-firmware drama

`kernel/sm8250/config/kernel-firmware.dat` (identical fork vs ROCKNIX): GPU
a650_gmu.bin/a650_sqe.fw/sm8250/a650_zap.mbn; adsp/cdsp.mbn + RB5 SLPI; Venus
vpu-1.0/venus.mbn; ath11k/QCA6390/hw2.0/*; qca/htbtfw20.tlv + htnv20.bin.
QCA6390 fw in upstream linux-firmware since Dec 2020. ROCKNIX extra-firmware
carries SM8250 blobs only for Thor Lite / Pocket Max — the RP5 needs nothing
vendor-only. Verify at first build: the Holo Core snapshot's linux-firmware
actually carries the ath11k/QCA6390 + qcom/sm8250 trees (the profile comment
still assumes ALARM's packages).

## 6. Other load-bearing facts

- Controller = MCU-over-UART serdev like rsinput in shape, but driver/DT/
  InputPlumber/FF/calibration all exist and are RP5-verified upstream. None of
  the rsinput saga transfers as work.
- Suspend: s2idle only (no S3 on mainline Qualcomm), working per ROCKNIX +
  pocknix ("SM8250 sleep/wake solid where SM8550 was experimental"). Small
  quirk set, already packaged (LEDs off pre-sleep, wcd938x runtime-PM off,
  audio re-kick = pocknix-sm8250-audio-resume.service). No drain measurements
  exist anywhere — measure early (Odin s2idle = 31mA reference).
- CPU topology: big cores cpu4-7 (vs 3-7 on sm8550), already in rp5.conf.
- SM8250 is one of the best-mainlined Qualcomm SoCs (linux-msm mainline-status).

## Recommended strategy

**Base: Holodor's own fork, not restructured upstream.** The sm8250 family is
already in-tree, pre-integrated with the harness Holodor has hardened; the
restructure would trade a working in-tree device for an ALARM harness needing
the Holo Core conversion redone. Keep the restructure merge parked separately.

Work order:
1. Build `DEVICE=sm8250` as-is; fix what the Holo-Core-era harness changes
   broke for a second, arm-efi SoC (pacman.conf/repo/signing paths = likely
   friction).
2. Cherry-picks: `8755514` (gpt cmdline — cheap, load-bearing), `82fbb2e`
   (7.2 resync — or stay on validated 7.1.2 initially), `d3b4743`/`a8b8635`
   (DXVK-2 donor — REQUIRED for Proton, adapt to seedless bootstrap),
   `fb6c759` (GPcal, nice-to-have).
3. Hardware validation on the real RP5 — the fork's sm8250 was validated on
   ALARM userland in July, never under Holo Core, never built on fusor.

**Freebies vs Odin 3**: no bootloader flashing/AVB exposure for SD boot; EDL +
published recovery images as un-brick floor; all firmware upstream; mature
turnip; working suspend; controller/panel/touch/rumble/charging done and
validated; ROCKNIX actively maintains the family. **Harder parts**: DXVK-2
donor x seedless bootstrap; Holo Core userland on a second SoC; transpose
panel under Holodor's gamescope (RP6 contract, but Holodor has only shipped a
native-landscape panel); everything unvalidated until first boot. **Unknowns**:
RP5 s2idle drain, 25.2.7-turnip Eden fault status (moot with mesa-next),
Flip 2 entirely unverified, exact stock boot-chain internals (cosmetic for
scoping — the stock chain demonstrably boots GRUB SDs).
