#!/bin/bash
# revert-lexar-k23.sh — if kernel 23 (phantom redriver removed, 2026-10-12 17:10) does not boot:
# put the previous boot image back. deploy-rp5.sh's alpm hook left /flash/KERNEL.bak = the image it
# built just before installing the 23 package (kernel 22 Image + 22 dtbs, same modules apart from the
# dts). Run on fusor with the card in the reader. Nothing is written until the FAT and KERNEL.bak are seen.
set -eu
dev=${1:-}
if [ -z "$dev" ]; then
  for d in /dev/sd? /dev/mmcblk?; do [ -b "$d" ] && echo "candidate: $d $(lsblk -dno SIZE,MODEL "$d" 2>/dev/null)"; done
  echo "usage: $0 /dev/sdX"; exit 1
fi
part=$(lsblk -nlo NAME,FSTYPE "$dev" | awk '$2=="vfat"{print "/dev/"$1; exit}')
[ -n "$part" ] || { echo "no vfat partition on $dev"; exit 1; }
m=$(mktemp -d); sudo mount "$part" "$m"
if [ -f "$m/KERNEL.bak" ]; then
  sudo cp "$m/KERNEL" "$m/KERNEL.k23" && sudo cp "$m/KERNEL.bak" "$m/KERNEL" && (cd "$m" && sudo sh -c 'md5sum KERNEL > KERNEL.md5') && sync
  echo "restored KERNEL from KERNEL.bak (kernel 22 image) on $part; the 23 image kept as KERNEL.k23: $(cat "$m/KERNEL.md5")"
else
  echo "no KERNEL.bak on $part"; ls -la "$m"
fi
sudo umount "$m"; rmdir "$m"
