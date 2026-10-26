# Boot measurement checklist (WP4 B0) — 2026-09-24

Purpose: produce before/after numbers for the boot trims (plan WP4, agenda section B) on
the SD card AND on the internal install, so every later change is judged against a
baseline instead of a stopwatch feeling. Run it once on the released 20260923e (or the
current card) BEFORE flashing anything with the kernel-28 DTB trim or the B8 image cleanup,
and again after each single change. Two boots per medium, power OFF between boots (an SD
boot after a warm reboot keeps nothing in RAM either, but the card and the UFS keep their
own caches; powering off is the only way to make the runs comparable).

Everything below is read-only on the device. Nothing here changes a unit, a file or a
setting. It needs a card with sshd enabled (the Lexar debug card has it; a release card
needs the INSTALL appendix: `passwd`, then `systemctl enable --now sshd` as deck) and
fusor's key for deck. Root commands run through `systemd-run --wait --pipe` because the
image has no sudo. Tools used are all on the image: `systemd-analyze`, `journalctl`,
`fincore`, `lsof`, `findmnt`, `stat`, `awk`. NOT on the image: `vmtouch`, `pidstat`,
`iostat`, `perf`, `strace` — do not plan on them.

Do not run this over the USB-C hub ethernet and then sleep the device (the hub kills the
USB host on resume); Wi-Fi at 192.168.1.32 is fine. Hold an inhibitor for the whole
session so the Odin does not idle-suspend between captures:

```
ssh deck@192.168.1.32
systemd-inhibit --what=sleep:idle --who=boot-measure --why="capturing boot numbers" sleep 7200 &
```

## 0. One-time: label the run

```
MEDIUM=sd            # or: internal   (what the ABL booted, not what is inserted)
RUN=~/boot-measure/$(date +%Y%m%d-%H%M)-$MEDIUM
mkdir -p "$RUN" && cd "$RUN"
findmnt -no SOURCE,FSTYPE / > root-device.txt          # /dev/mmcblk0p2 = SD, /dev/sda19-ish = UFS
cat /proc/cmdline > cmdline.txt
cat /proc/device-tree/model | tr -d '\0' > model.txt; echo >> model.txt
ls -la /flash/KERNEL /flash/KERNEL.md5 > flash-kernel.txt 2>&1   # size = which DTB payload booted
pacman -Q linux-pocknix-sm8750 pocknix-bsp-sm8750 pocknix-bsp-common pocknix-steam pocknix-boot-art > versions.txt
# wall-clock <-> monotonic anchor, so any absolute timestamp (Steam logs) converts to seconds-since-kernel-start
echo "$(date +%s.%N) $(cut -d' ' -f1 /proc/uptime)" > clock-anchor.txt
```

The RTC starts at 1970 on a fresh card until NTP syncs; that is why every number below
is taken in monotonic seconds (`short-monotonic`, `/proc/uptime`,
`*TimestampMonotonic`), never in wall-clock.

## 1. Right after Steam's first frame (do this FIRST, it is the perishable part)

Start the stopwatch at the power press. Note, by hand, into `stopwatch.txt`:
power press -> first splash frame (only handle we have on the ABL + kernel time),
-> splash gone, -> Steam's first frame. Then, within a minute:

```
cd "$RUN"
# 1a. systemd's view
systemd-analyze time              > analyze-time.txt
systemd-analyze blame             > analyze-blame.txt
systemd-analyze critical-chain    > cc-default.txt
systemd-analyze critical-chain getty@tty1.service      > cc-getty.txt
systemd-analyze critical-chain plymouth-quit.service   > cc-plymouth-quit.txt
systemd-analyze critical-chain multi-user.target       > cc-multi-user.txt
systemd-analyze critical-chain NetworkManager.service  > cc-nm.txt
systemd-analyze plot              > plot.svg
systemctl show -p ActiveEnterTimestampMonotonic -p InactiveExitTimestampMonotonic -p ExecMainStartTimestampMonotonic \
  plymouth-start.service plymouth-quit.service plymouth-quit-wait.service getty@tty1.service \
  systemd-user-sessions.service NetworkManager.service iwd.service pocknix-expand-root.service \
  pocknix-wifi-import.service inputplumber.service seatd.service udisks2.service upower.service \
  pocknix-decky-sync.service pocknix-decky-loader.service pocknix-lavd.service pocknix-powerd.service \
  pocknix-volumed.service pocknix-gamescope-rt.service local-fs.target basic.target multi-user.target \
  > unit-stamps.txt 2>&1
# the session-ready flag (deck's supervisor touches it; plymouth-quit waits for it): mtime in monotonic
python3 - <<'EOF' > session-ready.txt
import os,time
f='/run/user/1001/pocknix-session-ready'
try:
    m=os.stat(f).st_mtime; now=time.time(); up=float(open('/proc/uptime').read().split()[0])
    print("session-ready flag at monotonic %.2f s" % (up-(now-m)))
except FileNotFoundError: print("flag missing")
EOF

# 1b. what the deck session logged (gamescope + Steam client start); keep whole copies, they are small
cp ~/pocknix-session.log session.log 2>/dev/null
cp ~/pocknix-steam.log   steam-gamescope.log 2>/dev/null
stat -c '%n mtime=%y' ~/pocknix-session.log ~/pocknix-steam.log > log-mtimes.txt 2>/dev/null
# Steam's own logs carry wall-clock stamps -> convert with clock-anchor.txt. Which line is "first frame"
# is NOT established yet: keep the files, decide on the first run (candidates: the first
# steamwebhelper "Loaded" / gamepadui line in ~/.local/share/Steam/logs/*.txt, or the gamescope
# log's first "steam" window commit). Until then the stopwatch is the first-frame number.
mkdir -p steam-logs && cp ~/.local/share/Steam/logs/bootstrap_log.txt ~/.local/share/Steam/logs/console-linux.txt \
   ~/.local/share/Steam/logs/webhelper.txt ~/.local/share/Steam/logs/gamepadui*.txt steam-logs/ 2>/dev/null
ls -la --time-style=full-iso ~/.local/share/Steam/logs > steam-logs/ls.txt 2>/dev/null

# 1c. page-cache residency of the Steam tree = the hot set the first frame needed (B7 input).
#     Run BEFORE anything else warms the cache. Top by resident bytes; everything >1 MB.
find ~/.local/share/Steam -type f -size +1M -print0 2>/dev/null \
  | xargs -0 fincore -b -o RES,SIZE,FILE 2>/dev/null | sort -rn | head -200 > fincore-steam-top.txt
find ~/.local/share/Steam -type f -print0 2>/dev/null \
  | xargs -0 fincore -b -o RES,SIZE,FILE 2>/dev/null \
  | awk 'NR>1{r+=$1;s+=$2}END{printf "resident %.1f MB of %.1f MB in the Steam tree\n", r/1048576, s/1048576}' > fincore-steam-total.txt
# what the running client actually has mapped (no pgrep -f: it matches the shell running it)
for p in $(pidof steam steamwebhelper); do awk '$6 ~ /^\//{print $6}' /proc/$p/maps; done 2>/dev/null | sort -u > mapped-files.txt
```

## 2. Kernel side (root)

```
cd "$RUN"
systemd-run --wait --pipe --quiet -p User=root /bin/sh -c 'dmesg' > dmesg.txt 2>&1
systemd-run --wait --pipe --quiet /bin/sh -c 'journalctl -b -o short-monotonic --no-pager' > journal.txt 2>&1
systemd-run --wait --pipe --quiet /bin/sh -c 'journalctl -b -u systemd-udevd -u systemd-udev-trigger -u systemd-udev-settle -o short-monotonic --no-pager' > journal-udev.txt 2>&1
grep -n -m1 "Run /sbin/init" dmesg.txt          > dmesg-marks.txt     # kernel -> userspace handoff
grep -n -E "EXT4-fs \(.*\): mounted|mmc0: new|ufshcd|Freeing unused kernel|VFS: Mounted root|drm.*msm|adreno|Initramfs unpacking" dmesg.txt >> dmesg-marks.txt
head -400 journal.txt > journal-first400.txt
```

If `systemd-run --wait --pipe` asks for auth on a release card, the polkit rule for the
deck user is what grants it (50-pocknix-deck.rules); on the Lexar debug card it just works.

Reading the marks: `dmesg` t=0 is the kernel's first line, i.e. AFTER the ABL has read
and gunzipped KERNEL (the stopwatch power-press -> splash minus "Run /sbin/init" is
the only ABL number we can get). `systemd-analyze time` splits kernel / userspace.

## 3. After two minutes idle (the steady state, for B5)

```
cd "$RUN"
systemd-analyze blame > analyze-blame-late.txt         # oneshots that finished late show up here
top -b -n 1 -o %CPU | head -30 > top-idle.txt
cat /proc/loadavg > loadavg-idle.txt
free -m > free-idle.txt
systemctl list-units --type=service --state=running --no-pager > running-services.txt
systemctl list-dependencies network-online.target --reverse --no-pager > wants-network-online.txt   # B6
```

## 4. Optional, debug card only: disk read sampler through the boot

Not shipped; put it on the Lexar by hand, remove it after. Samples the root device's
sectors-read every 0.5 s for 40 s from local-fs on, so the IO-bound window (splash
hold vs Steam start) is visible without pidstat/iostat. Root device name from
`root-device.txt` (mmcblk0 on SD, sda on UFS).

```
# as root on the device (systemd-run --wait --pipe ... /bin/sh -c '...'), DEV=mmcblk0 or sda
cat > /etc/systemd/system/boot-disksample.service <<'EOF'
[Unit]
Description=debug: sample root-device reads through boot
DefaultDependencies=no
After=local-fs.target
[Service]
Type=simple
Nice=19
ExecStart=/bin/sh -c 'for i in $(seq 80); do echo "$(cut -d" " -f1 /proc/uptime) $(awk "\\$3==\\"$DEV\\"{print \\$6}" /proc/diskstats)"; sleep 0.5; done > /var/tmp/boot-disksample.txt'
[Install]
WantedBy=sysinit.target
EOF
systemctl enable boot-disksample.service
# reboot, then: cp /var/tmp/boot-disksample.txt "$RUN"/ ; systemctl disable boot-disksample.service; rm /etc/systemd/system/boot-disksample.service
```

Column 2 is cumulative sectors read (512 B); the slope between the splash-quit stamp and
the Steam first-frame stamp tells whether that gap is IO-bound (B7 worth doing) or
CPU-bound (it is not).

## 5. Bring the numbers to fusor

```
# from fusor (deck has fusor's key, not the other way round)
mkdir -p ~/projects/holodor/build/boot-measure
scp -r deck@192.168.1.32:boot-measure/ ~/projects/holodor/build/boot-measure/
```

Then fill one row per boot:

| run | medium | KERNEL size | splash (stopwatch) | plymouth-start ActiveEnter | getty@tty1 | session-ready | plymouth-quit | gamescope DRM (steam-gamescope.log) | first frame (stopwatch) | resident Steam MB |
|---|---|---|---|---|---|---|---|---|---|---|

Baseline expected from HANDOFF 09-23 (SD, 60 MB KERNEL): splash 3.5-5.7 s, getty ~7.5 s,
session ~8.6 s, quit ~10.5 s, gamescope DRM ~11.1 s, first frame +3-5 s. No internal
numbers exist yet.

## 6. What each later change is judged on

- B1 (kernel-28 DTB trim, KERNEL 60.4 -> 18.8 MB): stopwatch power-press -> splash, and
  `dmesg`'s first line vs stopwatch. Expect the ABL read/gunzip to drop; kernel time unchanged.
- B8 (image without Holo's linux/mkinitcpio/dracut): no boot change expected; `pacman -Q linux`
  must fail, `du -sh /usr/lib/modules` ~331 MB (7.1.3 only).
- B3 (getty ordering): `cc-getty.txt` — is systemd-user-sessions waiting on NetworkManager /
  iwd? Only then is the reorder worth it.
- B5 (Nice on daemons): `analyze-blame.txt` + the disk sampler slope between quit and first frame.
- B7 (SD read-ahead): `fincore-steam-top.txt` decides the list; the gap quit -> first frame is
  the number.
- B4 (expand-root): `analyze-blame.txt` line for pocknix-expand-root.service (the script already
  exits on its flag; only the unit start is left).
