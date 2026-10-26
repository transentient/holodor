#!/bin/sh
# Holodor: switch Holodor ABL / OpenABL / ROCKNIX ABL boot mode to Linux (Holodor),
# auto-export Android's saved Wi-Fi credentials to the Holodor SD card's wifi.txt (if not yet imported),
# and reboot from Android.
sh -c '
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
      gs=$(printf "%s\n" "$gs" | sed "s/&lt;/</g; s/&gt;/>/g; s/&apos;/'"'"'/g; s/&quot;/\"/g; s/&amp;/\&/g")
      gp=$(printf "%s\n" "$gp" | sed "s/&lt;/</g; s/&gt;/>/g; s/&apos;/'"'"'/g; s/&quot;/\"/g; s/&amp;/\&/g")
      WCC=$(cmd wifi get-country-code 2>/dev/null | tr " " "\n" | grep -E "^[A-Za-z]{2}$" | tail -n 1)
      [ -z "$WCC" ] && WCC=$(getprop ro.boot.wificountrycode 2>/dev/null | grep -E "^[A-Za-z]{2}$")
      { printf "ssid=%s\npassword=%s\n" "$gs" "$gp"; [ -n "$WCC" ] && printf "country=%s\n" "$WCC"; } > "$M/wifi.txt" 2>/dev/null
    fi
  fi
  [ "$UM" = "1" ] && { umount "$M" 2>/dev/null; rmdir "$M" 2>/dev/null; }
fi
DEV=/dev/block/by-name/devinfo
OOFF=$(grep -abo "OablSettings" "$DEV" 2>/dev/null | head -n 1 | cut -d: -f1)
if [ -n "$OOFF" ] && [ "$OOFF" -ge 2456 ]; then
  B=$(dd if="$DEV" bs=1 skip=$((OOFF + 58)) count=1 2>/dev/null | od -An -tu1 | tr -d " ")
  if [ -n "$B" ]; then
    printf "\\$(printf "%03o" $(((B & 252) | 1)))" | dd of="$DEV" bs=1 seek=$((OOFF + 58)) count=1 conv=notrunc 2>/dev/null
  fi
  if [ -b /dev/block/by-name/HOLODOR ] || [ -b /dev/block/by-name/ROCKNIX ]; then
    BS=$(dd if="$DEV" bs=1 skip=$((OOFF + 60)) count=1 2>/dev/null | od -An -tu1 | tr -d " ")
    if [ -n "$BS" ] && [ $(((BS & 7))) -eq 3 ]; then
      printf "\\$(printf "%03o" $(((BS & 248) | 1)))" | dd of="$DEV" bs=1 seek=$((OOFF + 60)) count=1 conv=notrunc 2>/dev/null
    fi
  fi
fi
OFF=$(grep -abo "BootMode" "$DEV" 2>/dev/null | head -n 1 | cut -d: -f1)
if [ -n "$OFF" ] && [ "$OFF" -ge 2456 ]; then
  printf "\x00" | dd of="$DEV" bs=1 seek=$((OFF + 56)) count=1 conv=notrunc 2>/dev/null
fi
sync && (svc power reboot 2>/dev/null || reboot)
'
