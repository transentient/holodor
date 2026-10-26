#!/bin/bash
# deploy-rp5.sh — install the staged cure bundle on a reachable RP5, from fusor:
#   tools/dock/deploy-rp5.sh [deck@192.168.1.68] [--kernel (implies --reboot)] [--reboot] [--skip-postmortem]
# Order (HANDOFF 2026-10-11): postmortem.sh first (PMIC reason + previous boot), then
# `pacman -U` the newest pocknix-bsp-common / pocknix-bsp-sm8250 / pocknix-steam from
# build/localrepo/sm8250 (the kernel package only with --kernel: a kernel is installed as a
# PACKAGE, its alpm hook rebuilds /flash/KERNEL, never a bare KERNEL swap), pocknix-powerd from
# the overlay to /usr/local/bin, the blackbox recorder as a service, then the versions.
# Holds a sleep:idle inhibitor while it runs and STOPS it at the end (the device goes back to
# Cliff with no claude-inhibit-* unit alive); --reboot reboots at the end instead.
set -u
H=deck@192.168.1.68; KERNEL=0; REBOOT=0; PM=1
while [ $# -gt 0 ]; do
  case "$1" in
    --kernel) KERNEL=1 ;;
    --reboot) REBOOT=1 ;;
    --skip-postmortem) PM=0 ;;
    -*) echo "unknown option $1"; exit 2 ;;
    *) H=$1 ;;
  esac
  shift
done
# A kernel package replaces /usr/lib/modules/7.1.2 under the RUNNING kernel: any module loaded
# after that (hub, DP alt mode, ...) is the new build's and the old kernel refuses it (BTF
# validation, 10-11). So --kernel always reboots at the end.
[ "$KERNEL" = 1 ] && REBOOT=1
D=$(cd "$(dirname "$0")" && pwd)
R=$(cd "$D/../.." && pwd)
REPO="$R/build/localrepo/sm8250"
SSH="ssh -o ConnectTimeout=8 -o BatchMode=yes"
root() { $SSH "$H" 'systemd-run --wait --pipe --collect -q bash -s'; }   # script on stdin runs as root

newest() { ls -v "$REPO"/"$1"-*.pkg.tar.zst 2>/dev/null | grep -v -- '-debug-' | tail -n 1; }
PKGS=()
for p in pocknix-bsp-common pocknix-bsp-sm8250 pocknix-steam; do
  f=$(newest "$p"); [ -n "$f" ] || { echo "no $p package in $REPO"; exit 1; }; PKGS+=("$f")
done
[ "$KERNEL" = 1 ] && { f=$(newest linux-pocknix-sm8250); [ -n "$f" ] || { echo "no kernel package in $REPO"; exit 1; }; PKGS+=("$f"); }
POWERD="$R/overlay/usr/local/bin/pocknix-powerd"
[ -f "$POWERD" ] || { echo "no $POWERD"; exit 1; }

echo "== target $H"; $SSH "$H" true || { echo "unreachable"; exit 1; }
echo "== installed now"; $SSH "$H" 'pacman -Q pocknix-bsp-common pocknix-bsp-sm8250 pocknix-steam linux-pocknix-sm8250 2>&1'
echo "== bundle"; printf '  %s\n' "${PKGS[@]##*/}" "pocknix-powerd ($(md5sum < "$POWERD" | cut -c1-8))" "pocknix-blackbox.service + blackbox.sh + pon-reason.sh"

echo "== inhibit idle sleep for the deploy (claude-inhibit-deploy, 20 min cap)"
$SSH "$H" 'systemd-run --unit=claude-inhibit-deploy --collect -q systemd-inhibit --what=sleep:idle --who=claude-deploy --why="package deploy from fusor" sleep 1200' 2>&1 | grep -v '^Running as unit' || true
cleanup() {
  echo "== release the inhibitor"
  root <<'EOS'
systemctl stop claude-inhibit-deploy.service 2>/dev/null
systemctl list-units --plain --no-legend 'claude-inhibit-*' 2>/dev/null | grep . && echo "WARNING: claude-inhibit-* units still alive" || echo "no claude-inhibit-* unit left"
EOS
}
trap cleanup EXIT

if [ "$PM" = 1 ]; then
  echo "== postmortem first"; "$D/postmortem.sh" "$H"
fi

echo "== copy"
$SSH "$H" 'mkdir -p /home/deck/deploy'
scp -q "${PKGS[@]}" "$POWERD" "$D/pocknix-blackbox.service" "$D/blackbox.sh" "$D/pon-reason.sh" "$H:/home/deck/deploy/" || exit 1

echo "== install (root)"
{
  echo 'set -u; cd /home/deck/deploy || exit 1'
  printf 'pacman -U --noconfirm'; for f in "${PKGS[@]}"; do printf ' %q' "${f##*/}"; done; echo ' 2>&1 | grep -vE "^\(|^::|^ *$" | tail -n 40'
  cat <<'EOS'
install -m755 pocknix-powerd /usr/local/bin/pocknix-powerd && echo "pocknix-powerd installed ($(md5sum < /usr/local/bin/pocknix-powerd | cut -c1-8))"
install -m644 blackbox.sh pon-reason.sh /home/deck/ && chown deck:deck /home/deck/blackbox.sh /home/deck/pon-reason.sh
systemctl stop pocknix-blackbox.service 2>/dev/null   # the transient recorder postmortem.sh may have started
install -m644 pocknix-blackbox.service /etc/systemd/system/pocknix-blackbox.service
systemctl daemon-reload
systemctl enable --now pocknix-blackbox.service >/dev/null 2>&1 && echo "pocknix-blackbox.service enabled + running"
systemctl restart pocknix-powerd.service && echo "pocknix-powerd restarted"
echo "-- versions"; pacman -Q pocknix-bsp-common pocknix-bsp-sm8250 pocknix-steam linux-pocknix-sm8250
echo "-- units"; for u in pocknix-powerd pocknix-blackbox pocknix-wifi-heal-boot pocknix-game-affinity; do printf '  %s: %s / %s\n' "$u" "$(systemctl is-enabled $u.service 2>&1)" "$(systemctl is-active $u.service 2>&1)"; done
echo "-- sleep.d"; ls /usr/lib/pocknix/sleep.d/pre /usr/lib/pocknix/sleep.d/post | tr '\n' ' '; echo
echo "-- heal boot unit Type"; grep -E '^Type=' /usr/lib/systemd/system/pocknix-wifi-heal-boot.service
echo "-- /flash"; ls -l /flash/KERNEL* 2>/dev/null; md5sum /flash/KERNEL* 2>/dev/null
EOS
} | root

if [ "$REBOOT" = 1 ]; then
  trap - EXIT
  echo "== reboot (the inhibitor dies with it)"
  root <<'EOS'
systemctl stop claude-inhibit-deploy.service 2>/dev/null
systemctl reboot
EOS
fi
