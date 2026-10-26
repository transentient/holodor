#!/bin/sh
# Holodor: flash the Holodor ABL bootloader (Retroid Pocket 5 / Mini / Flip 2, Qualcomm SM8250) to both bootloader slots.
# Run from Android's "Run script as Root". Refuses to run on a different chip or unsupported device.
ELF="/sdcard/rocknix_abl/abl_signed-SM8250.elf"
PLAT=$(getprop ro.board.platform 2>/dev/null)
MODEL="$(getprop ro.product.model 2>/dev/null) $(getprop ro.product.vendor.model 2>/dev/null) $(getprop ro.product.manufacturer 2>/dev/null) $(getprop ro.build.product 2>/dev/null)"
COMPAT=""
for f in /proc/device-tree/compatible /sys/firmware/devicetree/base/compatible /proc/device-tree/model /sys/firmware/devicetree/base/model; do
  [ -r "$f" ] && COMPAT="${COMPAT} $(tr '\0' ' ' < "$f")"
done
SEEN="${PLAT} ${MODEL} ${COMPAT}"
case "$SEEN" in
  *kona*|*sm8250*) ;;
  *[a-zA-Z]*) echo "flash_abl.sh: REFUSED — this bootloader is for SM8250 devices only."
              echo "This device reports: $SEEN. Nothing was written."
              exit 1 ;;
esac
case "$(printf "%s" "$SEEN" | tr "A-Z" "a-z")" in
  *retroid*|*rp5*|*rpmini*|*flip2*|*moorechip*|*ayn*|*thor*|*mangmi*|*pocket*) ;;
  *)
    echo "flash_abl.sh: REFUSED — unrecognized SM8250 device ($SEEN). To prevent bricking Secure-Boot-fused phones/tablets, only supported handhelds are allowed."
    exit 1 ;;
esac
[ -f "$ELF" ] || { echo "flash_abl.sh: $ELF not found. Copy the whole rocknix_abl folder to Internal storage first."; exit 1; }
ELF_SZ=$(wc -c < "$ELF" 2>/dev/null | tr -d " ")
[ "${ELF_SZ:-0}" -gt 200000 ] || { echo "flash_abl.sh: $ELF is truncated (${ELF_SZ:-0} bytes). Nothing was written."; exit 1; }
if [ ! -s /sdcard/rocknix_abl/abl_a.img ] || ! grep -aq "openabl-menu" /dev/block/by-name/abl_a 2>/dev/null; then
  dd if=/dev/block/by-name/abl_a of="/sdcard/rocknix_abl/abl_a.img" bs=1M 2>/dev/null
  dd if=/dev/block/by-name/abl_b of="/sdcard/rocknix_abl/abl_b.img" bs=1M 2>/dev/null
  [ -s /sdcard/rocknix_abl/abl_a.img ] && [ -s /sdcard/rocknix_abl/abl_b.img ] || {
    echo "flash_abl.sh: failed to back up stock abl_a/abl_b to /sdcard/rocknix_abl/. Aborting before write."
    exit 1
  }
  cp /sdcard/rocknix_abl/abl_a.img /sdcard/rocknix_abl/abl_b.img /mnt/media_rw/*/rocknix_abl/ 2>/dev/null || true
fi
dd if="$ELF" of=/dev/block/by-name/abl_a bs=1M || exit 1
dd if="$ELF" of=/dev/block/by-name/abl_b bs=1M || exit 1
WXML=""; for f in /data/misc/apexdata/com.android.wifi/WifiConfigStore.xml /data/misc/wifi/WifiConfigStore.xml; do [ -r "$f" ] && { WXML="$f"; break; }; done
if [ -n "$WXML" ]; then
  M=""; for d in /mnt/media_rw/*; do [ -f "$d/KERNEL" ] && { M="$d"; break; }; done
  UM=0
  if [ -z "$M" ]; then
    for b in /dev/block/by-name/HOLODOR /dev/block/by-name/ROCKNIX /dev/block/mmcblk0p1; do
      [ -b "$b" ] || continue
      M=/data/local/tmp/.holodor_fat
      if mkdir -p "$M" 2>/dev/null && mount -t vfat "$b" "$M" 2>/dev/null; then
        if [ -f "$M/KERNEL" ]; then UM=1; break; fi
        umount "$M" 2>/dev/null; rmdir "$M" 2>/dev/null
      fi
      M=""
    done
  fi
  if [ -n "$M" ] && [ -f "$M/KERNEL" ] && [ ! -f "$M/wifi.txt" ] && [ ! -f "$M/wifi.txt.imported" ]; then
    s=""; p=""; gs=""; gp=""
    while IFS= read -r line; do
      case "$line" in
        *"<WifiConfiguration>"*) s=""; p="" ;;
        *name=\"SSID\"\>\&quot\;*\&quot\;\</string\>*) s="${line#*name=\"SSID\">&quot;}"; s="${s%&quot;</string>*}" ;;
        *name=\"PreSharedKey\"\>\&quot\;*\&quot\;\</string\>*) p="${line#*name=\"PreSharedKey\">&quot;}"; p="${p%&quot;</string>*}" ;;
        *"</WifiConfiguration>"*) [ -n "$s" ] && [ -n "$p" ] && { gs="$s"; gp="$p"; } ;;
      esac
    done < "$WXML"
    if [ -n "$gs" ] && [ -n "$gp" ]; then
      gs=$(printf "%s\n" "$gs" | sed "s/&lt;/</g; s/&gt;/>/g; s/&apos;/'/g; s/&quot;/\"/g; s/&amp;/\&/g")
      gp=$(printf "%s\n" "$gp" | sed "s/&lt;/</g; s/&gt;/>/g; s/&apos;/'/g; s/&quot;/\"/g; s/&amp;/\&/g")
      WCC=$(cmd wifi get-country-code 2>/dev/null | tr " " "\n" | grep -E "^[A-Za-z]{2}$" | tail -n 1)
      [ -z "$WCC" ] && WCC=$(getprop ro.boot.wificountrycode 2>/dev/null | grep -E "^[A-Za-z]{2}$")
      { printf "ssid=%s\npassword=%s\n" "$gs" "$gp"; [ -n "$WCC" ] && printf "country=%s\n" "$WCC"; } > "$M/wifi.txt" 2>/dev/null
    fi
  fi
  [ "$UM" = "1" ] && { umount "$M" 2>/dev/null; rmdir "$M" 2>/dev/null; }
fi
sync
echo "flash_abl.sh: Holodor bootloader written to abl_a and abl_b (Retroid Pocket 5)."
