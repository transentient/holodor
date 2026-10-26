#!/bin/bash
# card-journal.sh /dev/sdX [boots]
# Read a Holodor SD card in fusor's reader WITHOUT writing to it: the last N boots' journals
# (one file each under /tmp/card-journal-b<N>.log, grepped for the wifi/usb/dock/power lines),
# the boot wifi-heal verdicts, NetworkManager's persisted radio state, systemd-rfkill's saved
# state, the PMIC reason log, the blackbox tail, and what /flash holds (KERNEL, KERNEL.k15).
# ext4 is mounted ro,noload (no journal replay = no write), vfat ro. Needs sudo (mount).
set -u
dev=${1:?usage: card-journal.sh /dev/sdX [boots]}
n=${2:-3}
p1=$(lsblk -nlo PATH,FSTYPE "$dev" | awk '$2=="vfat"{print $1; exit}')
p2=$(lsblk -nlo PATH,FSTYPE "$dev" | awk '$2=="ext4"{print $1; exit}')
[ -n "$p2" ] || { echo "no ext4 partition on $dev"; lsblk "$dev"; exit 1; }
mnt=$(mktemp -d /tmp/holodor-card.XXXX)
sudo mount -o ro,noload "$p2" "$mnt" || { rmdir "$mnt"; exit 1; }
trap 'sudo umount "$mnt" 2>/dev/null; rmdir "$mnt" 2>/dev/null' EXIT
J="$mnt/var/log/journal"
echo "== card $dev: $p1 (vfat) $p2 (ext4) mounted ro at $mnt"
echo "== boots in the journal (last $n)"
sudo journalctl -D "$J" --list-boots --no-pager 2>/dev/null | tail -n "$n"
pat='Linux version|ath11k|r8152|usb 1-|dwc3|xhci|HS-PHY|tcpm|typec|NetworkManager.*(wlan|wifi|radio|eth|enu|limited|manager)|iwd|rfkill|input current limit|Apsd|Oops|BUG:|Call trace|pocknix-usb-host|pocknix-powerd|pocknix-wifi|Power key|PrepareForSleep|Suspending|suspend entry|resume|Reached target|Shutting down|Powering off|rebooting'
for off in $(seq 0 $((n - 1))); do
  out="/tmp/card-journal-b$off.log"
  sudo journalctl -D "$J" -b "-$off" -o short-monotonic --no-pager > "$out" 2>/dev/null
  echo
  echo "== boot -$off: $(wc -l < "$out") lines -> $out"
  head -n 1 "$out"
  tail -n 1 "$out"
  grep -nE "$pat" "$out" | grep -vE 'systemd\[1\]: (Starting|Started|Finished)' | head -n 120
done
echo
echo "== /var/lib/pocknix/wifi-heal.log (tail)"; sudo tail -n 15 "$mnt/var/lib/pocknix/wifi-heal.log" 2>/dev/null || echo "(none)"
echo "== /var/lib/NetworkManager/NetworkManager.state"; sudo cat "$mnt/var/lib/NetworkManager/NetworkManager.state" 2>/dev/null || echo "(none)"
echo "== systemd-rfkill saved state"
for f in "$mnt"/var/lib/systemd/rfkill/*; do [ -e "$f" ] && echo "  ${f##*/}: $(sudo cat "$f")"; done
echo "== /var/lib/pocknix/pon-reason.log (tail)"; sudo tail -n 6 "$mnt/var/lib/pocknix/pon-reason.log" 2>/dev/null || echo "(none)"
echo "== /var/lib/pocknix/blackbox.log (tail)"; sudo tail -n 3 "$mnt/var/lib/pocknix/blackbox.log" 2>/dev/null || echo "(none)"
echo "== installed pocknix packages"; sudo ls "$mnt/var/lib/pacman/local" 2>/dev/null | grep -E '^(linux-pocknix|pocknix-)' | sort
if [ -n "$p1" ]; then
  fm=$(mktemp -d /tmp/holodor-flash.XXXX)
  if sudo mount -o ro "$p1" "$fm"; then
    echo "== /flash"; ls -la "$fm"/KERNEL* 2>/dev/null; md5sum "$fm"/KERNEL* 2>/dev/null
    sudo umount "$fm"
  fi
  rmdir "$fm"
fi
# Filesystem health, read-only (e2fsck -n never writes): a rootfs damaged by a power loss
# explains slow boots, splash hangs and services that never start. CARD_FSCK=0 skips it.
sudo umount "$mnt" 2>/dev/null; rmdir "$mnt" 2>/dev/null; trap - EXIT
if [ "${CARD_FSCK:-1}" = 1 ]; then
  echo "== e2fsck -n -f $p2 (read-only; a few minutes over the reader)"
  t0=$(date '+%Y-%m-%d %H:%M:%S')
  sudo e2fsck -n -f "$p2" 2>&1 | tail -n 25
  echo "== e2fsck exit: ${PIPESTATUS[0]} (0 clean, 4 errors left = damaged, 8 operational error)"
  echo "== reader I/O errors since the fsck started"
  sudo journalctl -k --since "$t0" --no-pager 2>/dev/null | grep -iE 'I/O error|critical (medium|target)|sense|reset' | tail -n 10 || true
fi
