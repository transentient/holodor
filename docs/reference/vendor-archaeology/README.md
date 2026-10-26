# Vendor archaeology — mining the device's own Android for driver ground truth

The Odin 3 dual-boots its stock Android. That Android is a **complete, working
reference implementation for every piece of hardware we're bringing up** — and it's
sitting on the same UFS we already have root access to from Linux. When a mainline
driver misbehaves and the docs don't exist, the answers are on the device:

| What you need | Where it lives | How to get it |
|---|---|---|
| Board wiring (DT: interrupts, GPIOs, MBHC config, regulators) | `dtbo_a/b` + `vendor_boot_a/b` partitions | `dd` over ssh → `tools/vendor-archaeology/split_dtbo.py` / `split_vboot.py` → `dtc -I dtb -O dts` |
| Vendor kernel driver binaries | `vendor_dlkm` **logical** partition inside `super` | `tools/vendor-archaeology/lpparse.py` on the first 2MB of `super` → `dd` just the extent (142MB, not 12GB) → mount ext4 ro → `lib/modules/*.ko` |
| Vendor driver **C source** | OEM GPL kernel dumps on GitHub | Search symbol/file names from the .ko (`nm`, `strings`) — NothingOSS, OnePlusOSS, Xiaomi/Sony trees ship qcom-opensource driver dirs matching the same msm kernel branch |
| Working runtime register state | boot Android, use the root-script runner | one-liners only (RunScriptActivity ships lines independently); `mount -t debugfs` first |

## Lessons that made it work (2026-08-13, headphone jack campaign)

- **AYN's real DT hides behind Qualcomm model strings.** The dtbo carries 121 stock
  QC overlays; the Odin 3's is "Sun QRD SKU1" (dtbo_091–095) — identified by grepping
  the *blobs* for board-specific hardware (`awinic`, `htr3212`, `focaltech`), never by
  model name. `WCD_USBSS_BASE = (-1)` in vendor headers — watch for base-offset traps
  when mapping vendor register names to mainline.
- **Disassembly first, then source.** `aarch64-linux-gnu-objdump -dr` on the .ko gives
  (reg, mask, val) triples around `regmap_*` relocations — enough to reconstruct
  programming sequences. But the *source hunt* (symbol names → GitHub OEM trees)
  upgraded an asm reconstruction into line-for-line confirmed C within an hour.
  Prefer confirming both against each other.
- **Validate by hand-poking before building a kernel.** `i2ctransfer -f -y` (the `-f`
  is required while the driver holds the address) applied the vendor sequence live;
  headphone audio worked within minutes — that's what justified baking it into 0610 v4.
  Mind the paged-regmap desync risk: end pokes on the page the kernel last used.
- The recovered Qualcomm `wcd939x-i2c.c` (GPL-2.0, © Qualcomm, from OnePlusOSS
  sm8750 / NothingOSS sm8735 trees) + full register headers + the reversed analysis
  live in `qcom-wcd939x-usbss/`.

This generalizes to every remaining bring-up gap (and to the RP6/sm8550 port): the
vendor OS on the device is the datasheet.
