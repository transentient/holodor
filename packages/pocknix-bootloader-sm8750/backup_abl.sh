#!/bin/sh

# Backup abl_a and abl_b to internal storage, then copy the backup to the Holodor SD card too.

dd if=/dev/block/by-name/abl_a of="/sdcard/rocknix_abl/abl_a.img" bs=1M
dd if=/dev/block/by-name/abl_b of="/sdcard/rocknix_abl/abl_b.img" bs=1M
cp /sdcard/rocknix_abl/abl_a.img /sdcard/rocknix_abl/abl_b.img /mnt/media_rw/*/rocknix_abl/
