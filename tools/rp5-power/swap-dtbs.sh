#!/bin/bash
# swap-dtbs.sh apply|revert (run ON the RP5 as root): regulator-mode experiment, 2026-10-16.
# apply: back up the installed RP5 dtbs, install the edited copies from /var/tmp/dtb-exp/ (dtc -I dtb -O dts, edit,
# dtc -I dts -O dtb on fusor with the kernel tree's scripts/dtc/dtc), rebuild /flash/KERNEL. Used 10-16 for cycle X
# (s5a/s6a/s8c regulator-initial-mode 0x03 HPM -> 0x02 AUTO; opmode fast -> normal).
# revert: restore the backups and rebuild. A kernel package install also restores the packaged dtbs.
set -e
B=/var/tmp/dtb-backup; X=/var/tmp/dtb-exp; D=/boot/dtbs
case "$1" in
apply)
  mkdir -p $B; for f in sm8250-retroidpocket-rp5.dtb sm8250-retroidpocket-rp5-visionox.dtb; do [ -e $B/$f ] || cp -a $D/$f $B/$f; cp $X/$f $D/$f; done ;;
revert)
  for f in sm8250-retroidpocket-rp5.dtb sm8250-retroidpocket-rp5-visionox.dtb; do cp -a $B/$f $D/$f; done ;;
*) echo "usage: $0 apply|revert"; exit 1 ;;
esac
sha256sum $D/sm8250-retroidpocket-rp5*.dtb | cut -c1-16
command -v pocknix-build-bootimg >/dev/null && pocknix-build-bootimg || { echo "pocknix-build-bootimg not found"; ls /usr/lib/pocknix /usr/bin | grep -i bootimg; exit 1; }
ls -la /flash/KERNEL
