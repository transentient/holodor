# Odin 3 stick calibration: what is adjustable, and the smallest real fix (agent research, 2026-09-27)

Trigger: Cliff, Octopath Traveler, "left stick jumpy"; Steam's calibration screen shows only a
deadzone slider for non-Valve pads. Paths: rsinput = build/kernel/sm8750/linux-7.1.3/drivers/
input/joystick/rsinput.c; DTS = arch/arm64/boot/dts/qcom/cq8725s-ayn-common.dtsi.

## Adjustable knobs

| Knob | Where | Default (ours) | Runtime-writable | Takes effect |
|---|---|---|---|---|
| axis_{leftx,lefty,rightx,righty}_{min,center,max,deadzone,antideadzone} (20) | module_param 0660, rsinput.c:71-93 -> /sys/module/rsinput/parameters/ | +-1024 / 0 / dz 70 / adz 0 | yes, root; center/deadzone/antideadzone per frame (:305-319) | min/max/adz also change absinfo -> `echo 1 > update_params` (:269-288) AND an InputPlumber restart (IP reads absinfo once at open) |
| trigger_{left,right}_{max,deadzone,antideadzone} | :29-35, 63-69 | 0x610 / 0 / 0 | same | `z = trigger_max - raw` (:298-303) |
| update_params | :24,61 | 0 | write 1 | re-applies absinfo next frame |
| DT axis-range, axis-deadzone | probe :504-528; DTS :1202-1203 (1024, 70) | - | no | **overrides module params at probe**: a modprobe.d line for deadzone/min/max is clobbered; only center/antideadzone/trigger_* survive via modprobe.d |
| MCU SET_PAR bytes 0x28,0x07 | rsinput_init_commands :218-227 | debounce 40 counts, report period 7 | no (compile-time) | Armada 475b776 -> 0x06,0x02 = 250 Hz + 1-count analog resolution instead of a 40-count change threshold |
| MCU-internal hall calibration | MCU NVM; AYN Android "Joystick Calibration" writes it (Armada PR #437 draft documents cmds A0/A1, A2/A5 centre, A3/A6 table) | whatever Android last wrote | our driver has no read/write of it | applied INSIDE the MCU -> Android calibration is honoured under Holodor |

Raw ranges: ROCKNIX originals +-0x580 dz 0; 20-sm8750/1300 rescaled to +-1024 dz 70 (arrived with
the initial sync, no rationale recorded); 40-holodor/1300 (Armada-authored) adds the DT hook.
Armada 45b659e (PR #470, 09-18) dropped axis-deadzone 70 as "unmeasured" and lets Steam do
deadzones. Deadzone math is a hard cut, no rescale: `|x|<dz ? 0 : sign*(|x|-adz)` -> with dz 70
adz 0 the output jumps 0 -> 70 (6.8 %) as the stick leaves centre.

## Userspace path
InputPlumber (0.77.2 shipped, 0.81.0 built): composite 01-rsinput-controller.yaml -> deck-uhid.
No deadzone/calibration keys in the yaml schemas; normalize uses absinfo min/max only, ignores
flat; denormalize saturates. Useful: CompositeDevice.InterceptMode=2 lets a tool read the SOURCE
evdev while IP keeps the pad alive (Armada uses this). Steam sees a Deck; the uhid target answers
Steam's calibration GET_REPORT with fixed bytes and ignores SET_REPORT -> Steam's Deck-style
calibration UI is a no-op for us; only Steam Input's software deadzone applies, stacked on the
kernel's 70.

## GPcal port (worktree packages/pocknix-gamepad-calibration)
Stops inputplumber, reads raw evdev, writes /sys/module/*/parameters + update_params, persists
/etc/pocknix/gamepad-calibration.conf, replays via a unit Before=inputplumber.service. Already
device-agnostic (discovers the params dir). But: Pyxel/SDL desktop app, pkexec, not reachable
from Game Mode, Steam sees a disconnect. Reuse the restore unit + conf; not the UI.

## Armada
Armada Control Decky "Calibration" tab: polls EVIOCGABS on the source evdev under InterceptMode,
captures min/max/centre, inner = min(|neg|,|pos|), deadzone = max(7 % inner, 20), centre offset,
triggers span with 3 % deadzone; writes /etc/armada/input-calibration.json via the root helper;
armada-input-calibration.service Before=inputplumber replays the 26 params + update_params.
Open: #423 (triggers ~70 %, sticks ~90 % on some units) -> PR #556 decouples the 0x610 reference;
#326 (diagonals ~70 %); #437 draft = real MCU calibration wizard (WIP, NVM-writing).

## Pocknix Control pattern
plugin.json flags root; loader runs as root. Backend main.py -> py_modules/pocknix_control/
modes.py writing /var/lib/pocknix/* (atomically_write) or calling /usr/local/bin/pocknix-* via
run_cmd; config.py build_config(); Power.tsx STICK LEDS PanelSection + the 1 s fan_status poll are
the templates for sliders + a live readout.

## What "jumpy" could be -> knob
1. Stepping while moving (aim in ~4 % increments): the MCU's 40-count change threshold. Fix =
   Armada bytes 0x06,0x02. Kernel-only. TOP SUSPECT.
2. Jump on leaving centre: hard dz 70 / adz 0. Fix = antideadzone = deadzone (rescale) or dz 0.
3. Jitter at rest / drift: sensor noise or centre offset. Fix = per-axis center + deadzone, or the
   real one: AYN Android Joystick Calibration (MCU-persistent, honoured under Holodor).
4. Not reaching full deflection / weak diagonals: raw max < 1024 -> per-axis min/max +
   update_params + IP restart (#326/#423 family).

## OUTCOME 2026-09-27 evening: recommendation 1 is WRONG for Holodor
Kernel-30 shipped the 0x06/0x02 pair on RC 20260927. Measured with EVIOCGABS while InputPlumber
held the grab: left stick at rest LX +240 / LY -240, right stick RY +230 (of the advertised
+-1024), full deflection +-1320. Same board on kernel-28 (internal install): all zeros at rest.
So on MCU firmware V02.10.001.01 with our 7.1.3 rsinput, the "1-count / 250 Hz" parameters change
the analog report scale/centre, and Armada's driver (7.2.x, different frame handling) must be
compensating somewhere we do not carry. Reverted in kernel-31. The original "jumpy" complaint
(Octopath) is still open: measure the 40-count stepping on kernel-28 with the sampler first
(scratchpad stick-sample.py: polls absinfo at 50 Hz), then try dz 0 / antideadzone before any
MCU parameter change.

## Recommendation for the next RC (as written before the outcome above)
1. Kernel, one variable: 40-holodor/1301 flipping 0x28,0x07 -> 0x06,0x02 in rsinput_init_commands
   (never edit 20-sm8750/0031; sync.sh regenerates it). Risk low-medium: 5x UART frame rate
   through the resume path + checksum/reassembly; Armada has shipped it since 09-18.
2. Userspace "Sticks": /etc/pocknix/input-calibration.json + oneshot unit Before=inputplumber
   replaying the params (+update_params), plus a Pocknix Control STICKS section: per-stick
   deadzone / anti-deadzone sliders (immediate via sysfs, persisted), "Zero centre", "Capture
   range" (then update_params + systemctl restart inputplumber), "Reset", live raw readout via
   EVIOCGABS on the rsinput event node under InterceptMode=2. Keep DT 70 as the fallback. Effort
   1-2 days. Risks: IP restart on range save (brief disconnect), stacking with Steam Input's
   deadzone (document), triggers wait for #556. Check Armada's LICENSE before lifting text.
   Skip: GPcal UI (desktop-only), #437 MCU transport (draft).

## Verify on the device first
evtest on the rsinput node (InterceptMode 2 or IP stopped): rest noise/centre per axis; slow sweep
for 40-count steps (the K6 signature); full deflection + 8 compass points for raw max.
`grep . /sys/module/rsinput/parameters/*`, `dmesg | grep 'DT axis'`. Steam Input per-game deadzone
already stacked. Cliff: does AYN Android's Joystick Calibration change the Linux rest values.
After the K6 kernel: `journalctl -k | grep -i checksum` across suspend/resume cycles.

Sources: armada-os/armada PR #556, #470, #437, issues #423, #326, commit 475b776; InputPlumber
v0.81.0 src/input/event/evdev.rs, value.rs, target/steam_deck_uhid.rs, drivers/steam_deck/hid_report.rs.
