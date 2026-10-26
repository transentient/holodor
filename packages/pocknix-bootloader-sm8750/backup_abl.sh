#!/bin/sh
# Backup stock abl_a and abl_b to internal storage, then copy the backup to the Holodor SD card too.
if [ -s "/sdcard/rocknix_abl/abl_a.img" ] && grep -aq "openabl-menu" /dev/block/by-name/abl_a 2>/dev/null; then
  echo "backup_abl.sh: /sdcard/rocknix_abl/abl_a.img already exists and abl_a already has HolodorABL; keeping original stock backup."
  cp /sdcard/rocknix_abl/abl_a.img /sdcard/rocknix_abl/abl_b.img /mnt/media_rw/*/rocknix_abl/ 2>/dev/null || true
  exit 0
fi
dd if=/dev/block/by-name/abl_a of="/sdcard/rocknix_abl/abl_a.img" bs=1M
dd if=/dev/block/by-name/abl_b of="/sdcard/rocknix_abl/abl_b.img" bs=1M
cp /sdcard/rocknix_abl/abl_a.img /sdcard/rocknix_abl/abl_b.img /mnt/media_rw/*/rocknix_abl/ 2>/dev/null || true
sync
