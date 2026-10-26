# dock: the USB-C dock test matrix (dev only)

Written 2026-10-09 after the RP5 20261008 fresh-card boot had no sound: the DisplayPort audio
device (bsp-sm8250 27) had only ever been tested with the dock attached. Every dock change now
runs this matrix on a FRESH CARD, undocked first.

Rig: UGREEN USB-C dock -> HDMI -> MACROSILICON capture on fusor (`/dev/video0`, ALSA card
"Video"). `dockcheck.sh <rp5|odin3> ...` does the measuring over ssh; plugging is Cliff's, one
step per message, and each step ends with `dockcheck.sh <dev> run <label>` so the result is a
line in `results-<dev>-<date>.md`, not a memory.

| # | Step (Cliff) | Measure | Pass |
|---|---|---|---|
| 1 | cold boot, nothing plugged | `run undocked-boot` | DP disabled; default sink Speaker; Speaker + Headphones listed; `speaker` stream runs; `pulse` PASS; Cliff hears the tone |
| 2 | plug the dock after Steam is up | `wait enabled 30` then `run hotplug` | DP enabled within 30 s; frame VIDEO; default sink DisplayPort; tone HEARD |
| 3 | start a game, then `run docked-game` | | tone HEARD while the game runs; frame VIDEO |
| 4 | unplug the dock while the game runs | `wait disabled 30` then `run unplug-game` | default sink back to Speaker; Speaker stream runs; the game keeps running |
| 5 | plug again, then sleep (short power press), wake | `run wake-docked` | DP enabled; tone HEARD; frame VIDEO |
| 6 | unplug, sleep, wake | `run wake-undocked` | default sink Speaker; speakers play |
| 7 | power off; boot WITH the dock attached, 10 times | `run docked-boot-N` each time | Steam reaches game mode every time (logo hang = FAIL, journal saved); tone HEARD |
| 8 | hot-plug, 10 times, 20 s apart | `run replug-N` | tone HEARD every time (the DP AFE first-start timeout shows here) |
| 9 | pair the AtomS3U BLE pad (tools/blepad), docked | `blepad.sh dpad down` + `rp5shot.sh` | Steam adopts the pad (Xbox glyphs), the highlight moves; repeat after unplug and after wake |

Candidates under test (bsp-sm8250 29 + linux-pocknix-sm8250 15, 2026-10-09):
- U (userspace): HiFi-RP.conf makes the DisplayPort UCM device conditional on
  `/sys/class/drm/card0-DP-1/enabled`; `pocknix-dp-audio-watch` restarts WirePlumber when that
  changes so the card is re-probed. Steps 2 and 4 time the restart (expect ~1 s of silence).
- K (kernel): 0721 makes `msm_dp_audio_prepare` succeed with the link down, so a probe before the
  compositor lights the dock cannot drop the HiFi profile. Test U alone, then U+K, then K alone
  (bsp 27's unconditional device) on the same card.

Every `run` also does `pulse`: the tone through paplay, i.e. the PulseAudio layer Steam's UI, its
Chromium and most games use. `tone` alone is a native PipeWire client and passed on 20261008 while
every Pulse client was silent (the loudness filter classed Audio/Sink/Internal, bsp-sm8250 25..29;
fixed in 30). A result line without `pulse: PASS` is not a pass.

Not covered: a real TV (the capture's EDID is "HJW HD TO USB", 2-channel, no HDR); a second dock;
Bluetooth AUDIO while docked (the AtomS3U is BLE only; needs a real headset). Row 9 covers a Bluetooth
controller.

`frame` takes the 30th captured frame after a 3 s settle: the dongle's first frames after a lock are
black (2026-10-10, false BLACK on a live docked UI).

## Tools added 2026-10-11 (RP5 investigation)

- `postmortem.sh [deck@ip]` — first thing after a mystery reset: PMIC power-on/off reason (root,
  regmap debugfs), previous boot's journal tail, telemetry + blackbox tails, starts the recorder.
- `boot-journal-summary.sh deck@ip [-N]` — one boot's journal (short-monotonic) grepped for the
  dock/sleep/power/wifi/usb lines.
- `card-journal.sh /dev/sdX [boots]` — the same from a card in fusor's reader, without writing to
  it (ext4 `ro,noload`): last N boots, wifi-heal.log, NetworkManager.state, rfkill, pon-reason,
  blackbox, installed packages, /flash KERNEL md5, then a read-only `e2fsck -n -f` (CARD_FSCK=0 skips).
- `deploy-rp5.sh [deck@ip] [--kernel] [--reboot] [--skip-postmortem]` — postmortem, then
  `pacman -U` the newest bsp-common / bsp-sm8250 / steam from build/localrepo/sm8250 (kernel only
  with --kernel, as a package), pocknix-powerd from the overlay, the blackbox recorder as a
  service; holds and then releases a sleep:idle inhibitor.
