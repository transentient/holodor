#!/bin/sh
# Holodor: flash the ROCKNIX ABL bootloader (AYN Odin 3, Qualcomm SM8750) to both bootloader slots.
# Run from Android's "Run script as Root". Refuses to run on a different chip: an SM8750
# bootloader written to another device does not boot and needs an EDL restore.
ELF="/sdcard/rocknix_abl/abl_signed-SM8750.elf"
# Android names the SoC by codename (ro.board.platform: sun = SM8750); the device tree carries
# "qcom,sun" (vendor kernel) or "qcom,sm8750" (mainline). Any of them must match.
PLAT=$(getprop ro.board.platform 2>/dev/null)
for f in /proc/device-tree/compatible /sys/firmware/devicetree/base/compatible; do
  [ -r "$f" ] && { COMPAT=$(tr '\0' ' ' < "$f"); break; }
done
SEEN="${PLAT} ${COMPAT}"
case "$SEEN" in
  *sun*|*sm8750*) ;;
  *[a-z]*) echo "flash_abl.sh: this bootloader is for the AYN Odin 3 (SM8750) only."
           echo "This device reports: $SEEN. Nothing was written."
           exit 1 ;;
  *) echo "flash_abl.sh: could not identify the chip; continuing because you ran this on purpose." ;;
esac
[ -f "$ELF" ] || { echo "flash_abl.sh: $ELF not found. Copy the whole rocknix_abl folder to Internal storage first."; exit 1; }
dd if="$ELF" of=/dev/block/by-name/abl_a bs=1M || exit 1
dd if="$ELF" of=/dev/block/by-name/abl_b bs=1M || exit 1
echo "flash_abl.sh: ROCKNIX bootloader written to abl_a and abl_b (AYN Odin 3)."
