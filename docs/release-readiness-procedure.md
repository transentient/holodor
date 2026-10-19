# Release readiness procedure (RP5 lessons, written for the RP6 and every device after it)

Status: DRAFT 2026-10-16, written after the RP5 "ready to release" evening turned into a day of
showstoppers that an early measurement would have caught: the headphone jack clipping (config
rewrite shipped unmeasured), no internet after sleep (router class, never reproduced on purpose),
Steam UI on the slow cores (never measured), standby draining 2.5 %/h (never measured on battery;
the recon note had said "measure early" on 09-24). Internal engineering doc; the public docs keep
their own voice.

## Principles

1. Ground truth before theory: a counter, a trace, a measurement on the rig, the vendor's own
   driver source or live Android. Not a pattern from a sibling SoC, not a memory of a menu path.
2. Measure early, on the real configuration: battery, undocked, fresh boot of the image that will
   ship, the same way a user holds it. A docked overnight proves nothing about standby.
3. Every subsystem gets its number at bring-up, before any tuning: the number is the baseline that
   later changes are judged against. No number = not done.
4. A rewrite that replaces a measured recipe is unmeasured until re-measured on the device (the
   10-11 UCM rewrite shipped through five revisions with a clipped jack).
5. One variable per experiment, control first (what the vendor / ROCKNIX / Armada ship on the
   same device), the record checked before a gap is called new.
6. Nothing goes on the device without an inhibitor held as the first command of the block, and
   nothing stays on it: test rules, drop-ins, hooks, keys, radio-off states are removed before the
   device goes back to the human.
7. A fix that touches suspend, audio, display, USB-C or wifi re-runs the whole matrix below before
   it ships, not just the cell it fixed.

## Bring-up baseline (measure once, write the numbers into the device's results file)

| area | measurement | tool / method | pass line |
|---|---|---|---|
| standby drain | battery %, undocked, >= 6 h idle sleep from a fresh boot; plus `/sys/kernel/debug/qcom_stats` aosd/cxsd/ddr counts before/after one 2-min sleep via sleep.d edge snapshots | results file; `rtcwake -m no -s N; systemctl suspend` under the block, snapshots to /var/tmp | <= 1 %/h; counters moving (or the gap documented with the sleep-set trace) |
| deferred probes / sync_state | `/sys/kernel/debug/devices_deferred` empty; `dmesg | grep sync_state` quiet | boot log | empty, or each entry explained |
| awake idle power | battery current at a static Steam UI, screen at the default brightness, 60 s | `current_now` samples | number recorded |
| thermal + clocks | 10 min of a known game: temps, GPU/CPU clocks, fps | tools/rp5-bench | number recorded |
| speaker | tone at the default slider and at 100 % on the mic rig; THD and pumping at 100 % | tools/rp5-audio (NTG) | ceiling clean or the limit documented; 50 % "reasonable" by the owner |
| headphone jack | full-scale tone at 100 %: level + THD; probe+burst ducking; L/R | tools/rp5-audio/jack (UCA202, bare cable) | THD < 0.1 %, ducking < 1 dB, L=R within 0.5 dB |
| jack plug/unplug | route switches both ways; speaker comes back at its default, not 100 % | wpctl routes | yes |
| dock audio + video | first stream after dock plug, after undocked boot, after docked boot, after sleep docked | tools/dock | all pass |
| fresh undocked boot | profiles, one Steam audio device, speakers at the default, no DSP errors | tools/dock first-boot checks | pass |
| wifi after sleep | internet reachable after a 20+ min sleep AND after a 6 h sleep (router station aging) | gateway ping in the post-resume check log | reconnect or no action logged |
| Bluetooth audio | pair A2DP headphones; Steam lists one device; HFP noted if the kernel lacks RFCOMM | hands | pass or documented |
| Steam UI feel | library scroll smooth; where the UI threads run (`taskset -p`), GPU floor | ps -L / devfreq | big cores, documented floor |
| controls | sticks/triggers at the HID (absinfo), not through Steam's deadzone | tools (10-05 method) | offsets < 2 % |
| install paths | SD try-it-out; internal install over an existing Linux (replace path); uninstall; Android still boots; FRP state | hands + installer logs | all pass |
| RTC / clock | boot after a flat battery: time sane or synced before Steam | journal | pass |
| charging | docked and plain charger: input limit applied, 9 V contract where offered, no net drain at idle screen-on | PMIC regs + current | pass |
| USB roles | host on the dock after a wake; device mode on a PC | lsusb / dmesg | pass |

## Pre-release gate (the night before, on the image that ships)

1. Respin from the committed repo (device = repo; "in repo but not in the build" is not a state).
2. Write the card from fusor with full read-back (the reader drops windows), add the lab wifi file.
3. Fresh UNDOCKED boot of that card: the first-boot checks, then the jack and speaker numbers again.
4. Dock matrix on that boot, then one docked sleep, then undock and one undocked sleep with the
   counters.
5. Hand the device to the owner for the eye and ear items (slider, scroll, Bluetooth) on that boot.
6. Overnight: undocked, on battery, from a fresh boot, with the standby percentage written down in
   the morning. This is the item the RP5 release lacked.
7. Internal install from that card, Android boot still works, back to Linux.
8. Only then: release notes (known issues list = every red cell above), publish.

## Device-bring-up order for a new SoC (RP6 / sm8550)

1. Pull from Android first, before anything is flashed: full live DT (`dtc -I fs /sys/firmware/
   devicetree/base`), mixer_paths and ACDB, the lpm-levels / PSCI parameters, the charger limits,
   the panel timings, the audio HAL config. Keep them in tools/<device>-android/.
2. Boot the control (ROCKNIX / Armada nightly) and take the same baseline table on it: those are
   the numbers to beat, and they tell a platform gap from our bug on day one.
3. Our image: the baseline table, in the order of the table, each with its number, before tuning.
4. Standby measured on battery in the first week, with the SoC counters, with the sleep-set trace
   if the counters are zero.

## Lessons behind each line (where the RP5 record has the detail)

- jack: tools/dock/results-rp5-2026-10-15.md (CLS_H_ULP clip, include order); speaker: 10-13 path
  loss; dock: 10-14/10-15; wifi after sleep: 10-15 23:2x; standby + counters: 10-16; Steam UI
  cores + GPU floor: 10-16 00:3x; research: docs/aoss-deep-sleep-research.md (08-29).
