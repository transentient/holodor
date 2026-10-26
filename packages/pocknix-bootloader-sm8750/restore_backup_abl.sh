#!/bin/sh
[ -s "/sdcard/rocknix_abl/abl_a.img" ] && [ -s "/sdcard/rocknix_abl/abl_b.img" ] || {
  echo "restore_backup_abl.sh: /sdcard/rocknix_abl/abl_a.img or abl_b.img missing or empty; nothing written."
  exit 1
}
dd if="/sdcard/rocknix_abl/abl_a.img" of=/dev/block/by-name/abl_a bs=1M || exit 1
dd if="/sdcard/rocknix_abl/abl_b.img" of=/dev/block/by-name/abl_b bs=1M || exit 1
sync
