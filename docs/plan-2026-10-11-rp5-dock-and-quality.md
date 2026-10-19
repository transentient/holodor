# RP5: dock, keyboard sound, audio quality — findings and plan (2026-10-11)

Written while Cliff was out. Everything below was measured on the RP5 (20261010e card, docked on the
UGREEN dock) or read from code; provisional items are marked. Device-side tools used:
`tools/dock/postmortem.sh` (PMIC reset reasons + journal of the dead boot + recorder),
`tools/dock/blackbox.sh` (2 s flight recorder), `tools/dock/pon-reason.sh`.

## 1. The dock

### 1.1 The two "unexplained resets" of 2026-10-10 are two different things

**Death 2 (20:12, idle, docked) was not a reset.** The dead boot's journal on the card ends with a
normal systemd power-off:

| monotonic | line |
|---|---|
| 28 s | my inhibitor started: `systemd-inhibit --what=sleep:idle ... sleep 3600` |
| 3628 s | that inhibitor expired (60 min) |
| 3670 s | `systemd-logind: The system will suspend now!` (Steam's idle suspend, held back for an hour) |
| 3690 s | `Power key pressed short.` (wake) |
| 3695 s | `Power key pressed long.` then `Powering off...` |

Our power policy (bsp-common `20-pocknix-powerkey.conf`) mapped a 5 s hold to power off. The live
journal stream "ended abruptly" because a shutdown kills ssh sessions before it logs much.

**Answered 2026-10-11 14:10: nobody touched the device.** Cliff was downstairs at dinner. So the
device woke itself 20 s into the suspend and the kernel reported the power button held for 5 s:
a phantom. Mechanism, from the driver (`drivers/input/misc/pm8941-pwrkey.c`): the PMIC key is
reported from a read of the PON real-time status register inside the interrupt handler, with a
"simulate a press if we see a release without one" rule; one interrupt whose status read says
"down" with no release interrupt afterwards leaves KEY_POWER held in the kernel forever, and
logind only counts seconds. InputPlumber is not in this path (the RP5 config sources only the
gamepad; its virtual keyboard advertises KEY_POWER but never emits it). Cliff keeps the 5 s rule.

**Fix (bsp-common 30 + overlay `pocknix-powerd`, written 14:20, UNTESTED):** the long press moves
into our daemon. At the 5 s mark it reads the PMIC's PON_RT_STS register through regmap debugfs
(SID and PON base parsed from the key's sysfs path, GEN2 bit 0 / GEN3 bit 7) and powers off only
if the button is physically down; a phantom is logged and ignored. A stuck kernel key state
(which would swallow the next real press, since the input core drops same-value reports) is
detected by polling the key state every 5 s, and the release that clears it counts as a short
press. logind's `HandlePowerKeyLongPress` becomes `ignore`. Every power-key event is now
journaled with its source device, so the next phantom shows exactly where it came from.

**Death 1 (18:29, during dock replug cycle 2) is a real power loss.** Its boot has no shutdown
lines; the journal stops at the replug's DP-1 enable (the last seconds before a hard loss never
reach the card). Its PMIC reasons were overwritten by the later boots, so it has to be caught
again, with the recorder running and the reason read on the very next boot.

### 1.2 Docked, the RP5 runs on its battery (found, fixed in kernel 16, verification pending)

On the dock (PD contract 5 V / 2 A, Rp 3 A on CC) the PM8150B charger stays at the USB 2.0 default
input limit. Measured at 100 % battery, Steam home screen, docked:

| what | value |
|---|---|
| charger input limit (ICL_STATUS 0x1107) | 0x0a = 500 mA |
| charger `current_max` | 500000 |
| APSD (BC1.2 type detection) | never completes; "Apsd not ready" 3 lines/s all session |
| battery status / current | "Not charging", -190 to -247 mA (discharging) |
| PMIC die temperatures | 29-35 C |

Cause: the driver only ever programs the limit from the BC1.2 result, which a USB-C/PD source never
gives, and `USBIN_CURRENT_LIMIT_CFG` is ignored by the hardware unless `CMD_ICL_OVERRIDE` is set
(writing `current_max` as root changed nothing). ROCKNIX ships the identical driver (their 0011
patch is byte-identical to ours), so ROCKNIX and Armada RP5 users have the same cap. Inherited bug.

Fix, ours: `kernel/sm8250/patches/40-holodor/0722-pm8150b-charger-typec-pd-input-limit.patch`
(linux-pocknix-sm8250 16): the limit comes from the Type-C port manager's supply (PD contract, or
the Rp it saw), falling back to the PMIC's own Rp bits, BC1.2 only for legacy sources; override set
for anything above 500 mA; APSD re-run at most 5 times; `online` reported as a boolean (this also
ends upowerd's "online TRUE invalid gboolean" spam). Built and booted as a test kernel at 05:12
(docked). The device did not come back on the network and the dock HDMI stayed black; see 1.4.

### 1.2b The dead dock after sleep: mechanism and cure (written 2026-10-11 17:00, UNTESTED)

Mechanism, from `drivers/usb/dwc3/dwc3-qcom.c` and `core.c`: on system suspend the glue reads the
power-event status, prints `port-1 HS-PHY not in L2` when the HS PHY is still active, and cuts the
controller clocks anyway. With the RP5's `wakeup-source` on `usb_1` the dwc3 core keeps the host
alive across suspend (no `dwc3_core_exit`) and relies on the PHY being in L2; a dock or hub with an
active device keeps it out of L2, so the controller resumes corrupted: `xhci-hcd: WARNING: Host
System Error`, the hub is dropped, no re-enumeration, Type-C stuck in device role until a reboot
(RP5 2026-10-10 row 8; Odin 2026-09-07 with the ethernet hub). With nothing attached the warning
alone is harmless (09-07 control sleep).

Cure in software we own (bsp-common 31, `sleep.d/pre/010-usb-host` + `post/010-usb-host`): before
suspend, if any USB device is attached, the controller is taken out of host mode through dwc3's
debugfs `mode` switch (xhci removed, the device disconnected cleanly, the controller suspends
idle), and host mode is restored after resume, so the dock re-enumerates like a fresh plug. The dts
change (`usb_1` without `wakeup-source`) that 7c6613e added was REVERTED at 18:45, before any build:
in device mode dwc3 exits and re-initialises the core across suspend whatever the wakeup flag says
(`dwc3_suspend_common`, DEVICE case), so the hook already gives the attached case a full reinit,
while dropping the property would have changed the undocked sleep path that works today; and the
Odin's `usb_1` never had `wakeup-source` and still died 09-07, so the property is not the cure.
bsp-common 32 (built 18:49): the pre hook waits for the `mode` readback to say `device` (up to 5 s,
the time is logged) instead of sleeping 1 s, because the switch is a kernel work item (xhci removal
+ core soft reset) that the suspend must not race.

### 1.3 Still open on the dock, in order of user pain

1. **Docked wake shows nothing for ~74 s** (row 5). Users will hold the power button. Needs a
   gamescope/DRM look at the resume path (DP re-enable timing); until then the internal panel
   should at least light on wake.
2. **Dock plugged, idle sleep, unplug to wake: USB-C dead until reboot** (memory
   `reference-lan-static-ips`). TCPM's log is at
   `/sys/kernel/debug/usb/tcpm-c440000.spmi:pmic@2:typec@1500` (root) and will show where the PD
   state machine stops after that wake; read it right after a failed replug.
3. **Death 1**: power loss on a VBUS transition. Reproduce with 10 replugs 30 s apart while the
   recorder runs; read `pon-reason.sh` on the next boot (UVLO vs PS_HOLD vs fault settles it).
4. **Dock-at-boot freeze family** (10-09, and possibly 05:12 today): docked cold boots, 10 of them,
   recorder on, `pon-reason` after each failure.
5. ~~Power-key policy~~ decided 14:10: keep 5 s = power off, now PMIC-verified in `pocknix-powerd`
   (section 1.1). Still to learn: what wakes the device 20 s into a docked suspend, and whether
   the phantom key is the wake source itself (the kernel's wakeup-source counters and the
   journal of the next docked sleep will say).
7. **Docked idle sleep today (05:12 boot) woke with NO wifi and NO dock** (Cliff pressed power at
   ~14:00: panel lit, no wlan, dock HDMI black, neither the UGREEN dock nor the ethernet hub
   enumerated afterwards). On 10-10 a wake while still docked was "fine"; this one was not. The
   boot's journal (now `-b -1`) is the evidence; read it before anything else on the next contact.
6. PD above 5 V: our sink PDO is 5 V / 3 A only, so even a 9 V-capable dock gives at most 15 W.
   Worth a 9 V PDO once the SMB5's input-voltage window is confirmed (Android's choice is the
   reference). Not for this release.

### 1.4 The 05:12 test boot and recovery

The test kernel (`/flash/KERNEL`, md5 3acc947b...) replaced kernel 15, which is kept as
`/flash/KERNEL.k15`. The device was rebooted docked at 05:12 and had not reappeared by 05:30.
When Cliff is back:

1. Look at the panel. Press power once if dark. If it boots: run `tools/dock/postmortem.sh` first
   (the reason register tells power loss from hang), then check the recorder and
   `journalctl -k | grep "input current limit"` (expect 2000 mA on the dock) and that the battery
   current is zero or positive.
2. If it is stuck at the logo or never boots: hold power 10 s, boot again, undocked first.
3. If kernel 16 never boots: card into fusor, `build/revert-lexar-k16.sh /dev/sdX` puts kernel 15
   back (it refuses to touch a card without `KERNEL.k15`).

**19:00, from fusor (device still unreachable, card not in the reader):** the test Image on the card
reports `Linux version 7.1.2 ... #2 SMP PREEMPT Sun Oct 11 05:10:06`, vermagic `7.1.2 SMP preempt
mod_unload aarch64`; the kernel config has neither MODULE_SIG nor MODVERSIONS and the boot image's
ramdisk holds only the GPU firmware, so kernel 15's modules (ath11k_pci, r8152) load on it: a module
mismatch is ruled out. 0722 touches only the charger driver, registers its notifier after its own
supply, and has no path to wifi or USB. What is left is the journal on the card. Read, in this
order: `journalctl -D <mnt>/var/log/journal --list-boots`; per kernel-16 boot: `ath11k`, `r8152`,
`usb 1-`, `dwc3`, `NetworkManager`, `iwd`, `rfkill`, `radio`, `input current limit`,
`Oops|BUG|Call trace`; then `<mnt>/var/lib/pocknix/wifi-heal.log` (the boot heal logs what it saw on
every boot, incl. UNRECOVERED) and `<mnt>/var/lib/NetworkManager/NetworkManager.state`
(`WirelessEnabled`: our 000-wifi sleep hook turns the radio off through NetworkManager, which
persists it; a wake whose post hook never ran leaves wifi off at every later boot until the boot
heal's radio cycle ~2 min in). Kernel 17 (= 16 with 0722 v2, no dts change) was built and packaged at
18:55 (log build/kernel-sm8250-17.log); it replaces 16 in the deploy bundle and in build/image.

**20:15, from fusor:** the test KERNEL is proven to be kernel 15 plus the 0722 charger patch and
nothing else. Kernel 15 was taken from the 20261010f image's FAT partition and both boot images were
unpacked: embedded configs byte-identical (8580 lines), cmdlines identical, the same five dtbs with the
RP5 dtb byte-identical; the charger driver is built in, wifi is a module from the rootfs. So the kernel
side changed only the charger, and what the device did on those boots has to come from the journal. One
thing fusor could settle: our own boot wifi heal could produce the picture by itself. Its health test
was NetworkManager's internet check alone (an HTTP fetch from ping.archlinux.org), so any boot where that
was not `full` within 90 s ran the whole ladder, ending in a PCIe remove/rescan of the wifi chip, the
firmware reload that renamed the device on 10-05 and can fail to come back; and the boot unit was a
oneshot that multi-user.target waits for (systemd orders a target after everything it wants), so power
mode, game affinity and fan control waited ~2.5 min on such a boot. bsp-common 33 (UNTESTED) makes the
health test the LAN gateway answering a ping (or NM `full`), reserves the PCIe reset for a wifi device
that is gone or unusable, does nothing without a profile, and makes the boot unit Type=exec. Whether the
splash itself waited on the old unit is not established; the card's `wifi-heal.log` will say which branch
each dead boot took. `tools/dock/card-journal.sh` now ends with a read-only `e2fsck -n -f` of the rootfs.

**23:05, card read.** Root cause of the whole day: the bare KERNEL swap. The rebuilt Image's BTF differs
from the one the card's modules were built against, and the kernel is configured to refuse a module
whose BTF does not validate (`failed to validate module [ath11k] BTF: -22`, likewise bluetooth,
typec_displayport, lz4_compress, the LPASS audio macros and seven more), on every boot of that kernel.
No wifi driver means no wlan0; the zram swap and the wlan0 device unit then time out at 90 s, which is
the long splash; the boot wifi heal runs its full ladder on a device that is not there (its log says
UNRECOVERED four times), which is the ~2 min to multi-user; and the refused DP alt-mode driver is why
the device did not know it was docked. Kernel 15 on the same card shows none of this. I had called a
module mismatch ruled out at 18:35 on the strength of the version magic and the absence of MODVERSIONS;
that was wrong, BTF validation is a third gate. The card is reverted to kernel 15 (verified md5).
Kernel 18 adds MODVERSIONS (the real per-symbol ABI check) and MODULE_ALLOW_BTF_MISMATCH (a stale
module BTF no longer refuses the module), so a same-ABI swap boots and a real ABI change fails per
symbol with a readable message. The charger patch itself did what it should on the docked boot (1500
then 2000 mA), but the recorder shows the full battery still discharging at 50-200 mA under a 2 A
budget, so the drain has a second cause to find. pocknix-charge-full is not it (it only touches
charge_control thresholds, which the pm8150b driver does not expose); next is the PMIC itself, docked at
100 %: the AICL result and power-path status registers say whether the 2 A override actually took and what
the input settled at. Image 20261011 (kernel 18 + the four packages) was respun at 23:16 and flashed to the
Lexar at 23:18 on Cliff's go-ahead; he boots it tomorrow. The checklist for that boot is in HANDOFF.md.

**10-12 11:00, the drain explained without the device.** The saved docked blackbox (up=892 s) shows the chip
applying 500 mA (ICL_STATUS = AICL = 0x0a) while 0722 logged 2000 mA and tcpm held a 2 A PD contract: the
CMD_ICL_OVERRIDE bit v1/v2 set is the vendor driver's USB 2.0/3.0 (100/500/900 mA) override, not a high-current
one. v3 mirrors smblib_icl_override (USBIN_MODE_CHG + ICL_OVERRIDE_AFTER_APSD, override clear, APSD off during a
PD contract) = linux-pocknix-sm8250 19, untested. The RP5 died overnight on the powered Elecom hub (Cliff, 10-12
morning; state overnight unknown): consistent with a running device at a 500 mA input. The blackbox now records the
mode registers; pass = iclmax=28 docked and battery current >= 0.

## 2. The keyboard sound during setup

Cliff's question: should a touch on an on-screen-keyboard key make a sound? Steam's own code
(steamui `chunk~2dcc5aaf7.js`, module 97220, the keyboard's `HandleTouchStart`) does this on a
touch-start on a key:

1. `PlaySteamDeckHaptic(...)` with the keyboard's haptic settings, always;
2. `PlayNavSound(Typing)` only if `IS_STEAMOS` is false (module 72476, `rf` = `IS_STEAMOS`).

So on a Steam Deck (SteamOS) a touch tap gives a haptic pulse and no sound; the typing sound plays
for gamepad and hardware-keyboard activation (`KeyDown`). Our session is SteamOS to Steam
(`-steamos3`), so no sound is Steam's design, not an audio-stack fault. The 10-10 handoff's
"touch taps are silent by Steam's code path" stands, with the mechanism now known.

What we do not have is the haptic half. Verified on the device: gamescope's touch mode for the
Steam display is passthrough (`STEAM_TOUCH_CLICK_MODE = 4` on `:0`, set by Steam), so taps reach
Steam as real touch events and `HandleTouchStart` runs; the RP5's vibration motor is an evdev
force-feedback device (`spmi_haptics`, event0, FF capable). Routing Steam's Deck haptic pulses to
it through InputPlumber's deck target is a post-release feature, not a bug fix.

## 3. The audio stack: the honest picture

### 3.1 What changed over the weekend and what each change broke

| version | change | broke | inherited or invented |
|---|---|---|---|
| bsp 25 (10-06) | loudness filter hidden with `media.class Audio/Sink/Internal` | every PulseAudio client silent (20261008 clean card) | invented |
| bsp 27 (10-07) | DisplayPort UCM device | no sound at all on undocked boots | invented (ROCKNIX has no DP device) |
| bsp 28 (10-09) | DP device removed | nothing | revert |
| bsp 29 (10-09) | conditional DP device + watcher restarting WirePlumber | 31 s of auto_null on unplug, Steam deaf for the session | UCM `If` is standard; the poller is invented |
| bsp 30 (10-10) | filter back to `Audio/Sink` | Steam's "choose audio device" picker | return to standard |
| bsp 31 (10-10) | filter runs as its own `pipewire -c` process with the card's `device.id` | (none seen) | invented |
| bsp 32-33 | timeouts, ceiling 122, BindsTo | (none seen) | invented hardening |
| bsp 34 | restart only on plug; push default to Speaker on unplug | pins the Speaker as configured default (see 3.3) | invented |
| steam 53-54 | wait for pipewire-pulse before Steam | (none seen) | invented |

Cliff's "something that was a daemon is now a service" is bsp 31: the loudness filter used to be a
fragment inside the session's PipeWire daemon; since 31 it is a separate `pipewire -c` process
under a user service, because Steam folds a sink under "Built-in Audio" only when its `device.id`
names the real card, and that id exists only after WirePlumber has created the card. The audit
(3.2) confirms the standard way to do the same thing: WirePlumber 0.5.12 can load the filter-chain
inside its own process from a Lua script (`node/software-dsp.lua` is the upstream template), which
removes the extra process, the polling and the BindsTo/PartOf choreography. Recommended after the
release, not before.

### 3.2 Independent audit (second agent, static analysis, 2026-10-11)

Ranked failure scenarios, each with a mechanism in the code:

1. **Every WirePlumber restart (dock plug, docked wake) re-runs the UCM Speaker EnableSequence**,
   which turns the WSA companders back on and sets PA 12; nothing re-plants our gains. The 4-8 dB
   pumping ("warble") that bsp 21 fixed returns after the first dock plug until reboot. Dock tests
   measured a tone and clicks, which cannot show pumping.
2. **`hw:0` is assumed to be the RetroidPocket card** (heal and volume daemon). Any USB audio
   device present at boot (dock jack, headset, a mic) takes index 0 because the platform card
   registers 15-40 s late; the gains then land on the wrong card and the speakers stay at reset
   gains.
3. **Steam connects to PulseAudio once; on a slow boot only `auto_null` exists at that moment**
   (the launcher waits for pipewire-pulse, not for a sink).
4. **The watcher's `wpctl set-default` on unplug writes a persistent configured default**, so the
   Speaker beats a Bluetooth headset in every later session.
5. **`plant_hardware` can block forever** (192 KB write into pw-cat with no timeout when the sink
   is in error).
6. **Stale `device.id`**: the filter takes the first matching card object, which during a restart
   can be the dying one.
7. **Resume pins the quantum at 1024 for the rest of the session** (verbatim ROCKNIX; ~21 ms
   latency after the first sleep). Inherited; needs an on-device A/B before changing.
8. Minor: hard-coded `card0-DP-1`, uid 1001 in the resume unit, the 2 Hz poll if the card never
   appears.

Also from the audit: pipewire/pipewire-pulse are socket-activated and are pulled into the login
transaction only by the volume daemon's `Wants=`; the heal, `alsactl restore`, the UCM sequence and
the volume daemon all write the mixer with no ordering between them (the daemon's 121-then-122
trick makes it final at boot only).

### 3.3b The cure (bsp-sm8250 36, written 2026-10-11 17:00, UNTESTED): state that no restart can undo

The 3.2 audit's top item exists because the speaker's hardware state lived in scripts that run once
while the UCM verb included the upstream `wsa-macro` / `wsa881x` SpeakerEnableSeq files, which turn
the companders back ON and set PA 12 every time WirePlumber (re)creates the card. HiFi-RP.conf now
declares the complete state itself (companders OFF, WSA digital 122, PA 8, boost 8.5 V; headphones
class-AB, RX companders OFF, digital 122) in sequences that are idempotent, so a re-parse is
harmless by construction. The DisplayPort device is unconditional (kernel 0721 accepts an audio
prepare with the link down, so ACP can probe it undocked) with `DP0 Jack` + `JackHWMute Speaker`
driving availability, and `pocknix-dp-audio-watch` (the WirePlumber restart on dock plug) is gone.
To verify: a fresh UNDOCKED boot shows Speaker and Headphones (never auto_null); a dock plug moves
the default to DisplayPort with no restart; unplug moves it back; the mic shows no pumping after a
plug. The volume planter's "write during playback" trick stays until the idle-write question
(section 3.2 item "idle mixer writes don't land") is measured with the regmap cache bypassed.

Checked on fusor 18:40 (no device needed): `HiFi-RP.conf` parses (alsaucm 1.2.16 with a virtual card
and `${CardId}` substituted: the verb and all four devices load), and every control name it sets is
one the RP5 has shown (the 10-09 amixer dump, the earlier verbs, or the upstream codec files). One
design choice to confirm with Cliff on the device: the DisplayPort device declares
`JackHWMute "Speaker"` like the Headphones device does, so while a dock is in the Speaker is
unavailable and the default follows the dock without any watcher; the speaker is not selectable
while docked. Dropping that one line keeps both selectable (DP still wins by priority 300 > 100).

### 3.3 What I changed in response (bsp-sm8250 35, pocknix-steam 55, UNTESTED on a device)

- heal + volume daemon address the card by its `/proc/asound/cards` index (audit 2);
- volume daemon re-plants the gains when the Speaker sink is re-created (audit 1) and bounds
  pw-cat with `timeout 10` (audit 5);
- speaker-loud takes the last matching card object (audit 6);
- dock watcher drops the configured-default pin 2 s after pushing the Speaker (audit 4);
- launcher also waits, up to 20 s, for a default sink that is not `auto_null` (audit 3).

Each is a few lines and reversible. They are candidates: nothing goes into an image until they pass
the fresh undocked boot and dock rows 1, 2, 4, 5, 6 with the mic (a pumping test after a dock plug,
not just a tone). Audit 7 (quantum) and the WirePlumber-native filter are deliberately not touched.

## 4. Release recommendation

Hold 20261010f. Reasons: the dock power finding (1.2) means every docked user is slowly draining
while "charging", and the fix needs one verified docked boot; the audit found a docked-use audio
regression (3.2 item 1) that the dock matrix could not see; and the power-key policy (1.3 item 5)
deserves a decision before users hold the button at a dark dock.

Proposed path to the next RC, in order:

1. Verify kernel 16 docked: input limit 2000 mA, battery current >= 0, no APSD or upowerd spam,
   undocked boot unaffected (500 mA SDP on a PC port still works, charging on the wall charger).
2. Fresh undocked boot with bsp 35 + steam 55: sound, clicks, one audio device, slider law.
3. Dock rows 1, 2, 4, 5, 6 with the mic, plus a pumping measurement (tools/rp5-audio/pumptest.py)
   after a dock plug and after an unplug.
4. Death 1 and the docked-boot freeze with the recorder on (hands needed: 10 replugs, 10 docked
   boots).
5. Decide the power-key policy; write the release notes with the remaining known issues (docked
   wake delay, sleep-then-unplug USB).
6. Respin, one fresh boot, publish.

## 5. For Cliff, when back (one step at a time)

Done 14:00-14:30: the RP5 was asleep, not dead (so the 05:12 docked boot on kernel 16 worked);
it woke with no wifi and no dock; the 20:12 long press was nobody; the 5 s rule stays; the
keyboard haptic question is closed (this unit's motor is bad); Cliff is swapping the UGREEN dock
for the ethernet USB-C hub. Next: unplug, restart from Steam's power menu, plug the hub in; then
over ssh: postmortem (journal of the 05:12 boot), kernel 16 checks, install kernel 16 + bsp-common
30 + bsp-sm8250 35 + steam 55, deploy the new powerd, fresh undocked boot, dock rows with the mic.
