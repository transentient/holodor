# Holodor — road to release (written 2026-08-28)

> **Superseded 2026-09-04 by [plan-2026-09-04.md](plan-2026-09-04.md)** — Cliff's 8 points,
> mapped to status + steps + done-when. Phase details below remain the history.

Cliff's requirements, verbatim: **stable, stable, stable. Sleep that works — we had
that, we need it back. Smooth wake. RGB. Headphone jacks.**

Everything below is ordered by dependency. "Ceremony" = needs Cliff's hands; everything
else is agent-autonomous. Definition-of-done criteria are listed per phase — a phase is
not done until its criteria are measured, not vibed.

---

## Phase 1 — Sleep that works = AOSS deep sleep (REFRAMED 08-29)

**Root cause found 08-29: the SoC never reaches Qualcomm chip-level deep sleep.**
qcom_stats shows aosd/cxsd/ddr Count 0 across verified S3 suspends — CX rail and
DDR stay powered = a ~150–215 mA floor (≈2%/h) on EVERY kernel and even with all
of userspace stopped and radios off. The 08-26 "kernel-22 regression" framing was
wrong twice over: the Armada bundle is load-bearing (removing the MCU-quiesce patch
costs +380 mA), and the old "0.07–0.3%/h good era" was probably a capacity-%
measurement artifact — the one real-world data point (89%→dead in <40 h) matches
today's coulomb numbers. Suspend has likely always been ~2%/h on this port.

- [x] Kernel bisect + kernel-18 control + isolation soak (08-28/29) — evidence chain
      complete, soak-results.log + HANDOFF addendum.
- [x] Research sweep DONE — full findings + attack ladder in
      docs/aoss-deep-sleep-research.md. Headline: nobody has aosd/cxsd working on
      mainline sm8550/8650/8750; the TCS sleep-set flush only runs on the s2idle
      path (our "deep" S3 never exercises it), and PSCI OSI mode is a hard
      prerequisite. The unbooted-modem theory is unsupported — dropped.
- [x] Attack ladder rungs 1-3 CLIMBED 08-29: OSI "supported" per dmesg (enablement
      verification still open); s2idle switched (runtime); state1 sleep-window
      hooks (bsp-common-15); sync_state unblocked via fw_devlink.sync_state=timeout
      (GCC/GPUCC were blocked forever by the driverless coresight-tnoc DT node).
      Remaining rungs: bi_tcxo vote hygiene, pocknix RPMh regulator SLEEP-set pair
      (1046/1047) + regulator-state-mem DTS, rpmh read-back series, coresight DTS
      disable (cleaner than the timeout knob).
- [x] **STEADY-STATE MEASURED 08-30: 31 mA / 0.40%/h over a 17.4-h overnight window**
      (s2idle + state1 window + synced clocks) — 5-7x better than the shipped deep
      config, overnight costs ~7%, a full charge sleeps ~10 days. aosd still 0 =
      more upside remains (XO votes, regulator sleep-set port, OSI verification).
- [ ] s2idle validation ceremony (wake sources, suspend-mid-game, plugged sleep),
      then flip mem_sleep_default=s2idle in the shipped cmdline.
- [ ] Release positioning: overnight ≈ 7%, week-scale suspend viable; power off
      only for month-scale storage. Steam download suspend-inhibitor still wanted.
- [ ] Keep: wake-jank fix validated; suspend-mid-game works; plugged-in suspend safe.

- [x] Bisect variant kernels built on fusor (22.1 = −1005, 22.2 = −1006, 22.3 = −0701;
      built overnight 08-28, stashed in `~/odin3-backups/kernel-bisect-20260828/`)
- [x] Soak ceremony + patch conviction: SUPERSEDED — bisect ran 08-28/29, bundle
      acquitted (see above); the ladder replaced the per-patch hunt.
- [ ] Steam download suspend-inhibitor (we hold none — verified 08-28; SteamOS does).
      Fixes suspends-mid-download. Small bsp unit watching for active downloads.

**Done when:** unplugged deep-sleep drain ≤0.3%/h measured over a full overnight, AND
wake-jank stays fixed (zero rsinput frame errors, controls live post-wake), AND
plugged-in overnight suspend is clean, AND suspend-mid-game still works.

## Phase 2 — Stock restore + fresh install walkthrough (weekend ceremony)

Cliff's call 08-28: flash back to stock and go through the install once more.
This is the queued EDL plan + INSTALL.md validation in one block (~2-3h).

- [ ] **EDL/QFIL full factory restore** (Cliff on BONESAW, QPST/QFIL + CN tutorial in
      the EDL package). Wipes every UFS LUN to one matching Dec-2025 build. The SD
      card is untouched — current Holodor daily driver survives in hand.
      Pre-EDL rescue: already done (08-15/16, `~/odin3-backups/`); nothing new has
      been written to internal since (device SD-boots). Re-verify before flashing.
- [ ] **THE JACK TEST on stock Android, immediately** (Cliff asked not to be allowed
      to forget). Does Android auto-detect a 3.5mm plug? This decides the jack
      end-state:
      - Android detects → real gap on our side → resume MBHC detect hunt post-release
        (vendor DTB ground truth already mined; audio itself already works).
      - Android does NOT detect → manual output switching is **platform parity** →
        ship it documented, close the hunt for good.
- [ ] Does stock Android boot fully? (Expected yes — full-LUN reflash is the best
      theory for the old post-AVB failure. If it still fails: AYN email, but not
      release-blocking; Android is a bonus on this device now.)
- [ ] OTA Android up to current, then **INSTALL.md end-to-end as a fresh user**:
      ABL flash via Run-Script-as-Root from Android, boot the validated RC from SD,
      wifi.txt import, seedless bootstrap, OOBE. Then OTA to the Phase-3 respin when
      it lands — which validates the OTA path on a virgin install too.

**Done when:** jack question answered and logged, Android state known, INSTALL.md
walked start-to-finish by a human with no agent rescue.

## Phase 3 — RC respin with everything (agent work, gated on Phase 1)

- [x] Commit the 08-28 device-side wifi fixes to the repo (RC/repo parity rule):
      iwd roam thresholds now baked by build-sd-image.sh (RoamThreshold/5G=-85,
      Critical pair=-90). `autoconnect-retries=0` was ALREADY shipped in the
      importer — the sulky device profile was a manual UI dupe that lacked it.
- [x] **Charging trap fixed (08-28 finding, user-visible badly):** battmgr firmware
      DEFAULTS to an 80%/70% battery-care window; the 70% restart never fires in
      deep suspend, so "plugged in overnight" wakes at ~60%. New
      `pocknix-charge-full` boot unit (bsp-common-14) forces 100/95 until a real
      opt-in battery-care panel exists. Applied live on device too.
      Related open: post-dead-battery fuel-gauge readings jump wildly (61%→99%
      within minutes, charge_counter leaps) — recalibration artifact family;
      distrust single capacity reads after a full discharge.
- [ ] Kernel-2x: drain fix in, wake fixes kept, rumble + vol-up-must-not-wake
      validation (still pending from kernel-22 scoreboard).
- [ ] Sulk hardening: port upstream 696119c iwd/wlan0 boot-race fix.
- [ ] Splash-hold fix (the ~22s splash→gamescope dark gap + short-press death spiral
      — priority polish, turns the scariest-looking non-bug into a non-event).
- [ ] Download-inhibitor unit (Phase 1 item) in the image.
- [ ] Respin, loop-mount spot-check (always), flash, quick validation ceremony.

## Phase 4 — RGB (small, parallel to anything)

LEDs work (HTR3212 driver + `pocknix-stick-leds`, shipped 08-09). Remaining is UX:

- [x] RGB picker panel SHIPPED 08-31 (pocknix-decky-15): Stick LEDs QAM section,
      effect selector (off/static/rainbow/breathe) + 9 preset swatches (Hodor
      orange first). Backend pre-existed; daemon owns persistence
      (/var/lib/pocknix/led-{mode,color}), changes apply live.
- [x] 08-20 LED-off mystery: probable cause found — the shipped plugin dist was
      STALE (built 08-13, behind committed src); the rough LED dropdowns that DID
      ship were easy to trip. dist rebuilt + repo/dist parity restored. Defaults
      stay deliberate: off by default, picker enables. Confirm during soak week.
- [x] Lights-off-in-sleep hook — already shipped (bsp-common `leds-sleep-pre/post`
      stops the animator and zeroes the rings before suspend; verified 08-28).

## Phase 5 — Stability soak (the "stable, stable, stable" gate)

One week of daily-driver use on the frozen release stack. No new features enter
during the soak; only fixes for soak findings, which restart the clock on the
affected area.

**Soak pass criteria (a week with zero of):** forced power-holds, dead-controls
rescues, silent-audio boots (SoundWire race), wifi sulks (mitigation validation),
suspend wedges, overlay jams that need ssh rescue.

Known open bugs on the watch list, with rescues documented (docs/): overlay jam
(steamclient IPC family), VS controls-dead-at-launch race (quit+relaunch), SoundWire
codec enum race (reboot; probe-retry is the fix if it recurs in soak), flathub DNS
oneshot (restart clears; ordering fix queued), USBSS re-probe tripwire (watching).

## Phase 6 — Release mechanics

- [x] **License gate: RESOLVED.** pocknix-os#21 closed 2026-07-28; upstream now
      carries GPL-2.0 (LICENSE.md; maintainer also emailed Cliff). Verified via
      GitHub API 2026-08-28. Holodor's combined license = GPL-2.0 (upstream 2.0 +
      Armada 2.0-or-later + kernel patches all compose).
- [ ] Add Holodor's own LICENSE file (GPL-2.0, matching upstream — read their
      LICENSE.md text first for any or-later language) + final credits pass
      (ROCKNIX, Holo Core, ArmadaOS, batocera.pocket — tracked in README/PATCHES).
- [ ] Cliff decision: flip the repo public (can happen any time now — no longer
      coupled to anything external).
- [ ] Final image → archive.org (`holodor-odin3` identifier; metadata proposed to
      Cliff first — identifiers are permanent).
- [ ] OTA repo public flip per docs/pacman-repo.md checklist (coupled to license gate).
- [ ] Docs audit: Cliff rewrites public prose (plain language, hyphens not em-dashes,
      no jokes, conservative perf claims), agent audits accuracy.
- [ ] Website landing page refresh + announcement (Discord).

**Ship guards (never in a public image):** wifi PSK preseed, default passwords
unchanged (root/deck `pocknix` — change flow needed), seeded Steam client, telemetry
loggers, LED/test debris.

---

## Timeline sketch (Cliff-time is scarce; agent front-loads)

- **Fri 08-28 eve:** Phase 1 soak ceremony (~2h, mostly idle waiting)
- **Weekend 08-29/30:** Phase 2 block (EDL + jack test + install walkthrough)
- **Next week:** Phase 3 respin + Phase 4 RGB; Phase 5 soak starts on the respin
- **~Mid-September:** release, if the soak is clean and the license gate opens

The one watch item that could move the date: the 1006 drain/wake tension (may need
a real kernel fix, not a revert). The license gate resolved 07-28 (see Phase 6) —
nothing external blocks the release anymore.

## Phase 7 - After release: HDR, fresh graphics stack, dock and Bluetooth (Cliff, 2026-09-13)

Cliff's call after the Armada comparison (docs/armada-comparison-2026-09-13.md): pivot to
these right after the release, in this order.

1. **HDR.** Armada lists experimental HDR on the Odin 3 (release notes 20260817 and
   20260907). Nothing researched on our side yet: what their gamescope and kernel carry
   for HDR output on this panel, and what Holo Core's gamescope build lacks.
2. **Kernel and Mesa refresh.** We ship kernel 7.1.3 with the ROCKNIX patch series and
   Mesa 26.3-devel pinned to one commit; Armada is on 7.2.3 and Mesa 26.2.2. The
   Linux 7.2 bump was deliberately parked in August (HANDOFF, 08-28 sync notes). Take
   it as one cycle: kernel first, then Mesa, harness A/B before deploy, per the
   existing pin rules.
3. **Dock to a TV** (2026-09-24: promoted to WP9 in docs/plan-2026-09-24-next-release.md;
   Cliff: "make the docked-to-your-TV experience as good as possible"). External display over USB-C (Armada advertises external monitor
   output in Game Mode, so the kernel path exists upstream). USB host mode is proven on
   our side (the ethernet hub, 09-07). Open questions: DisplayPort alt mode on this
   kernel, gamescope output switching, audio over the dock.
4. **Bluetooth controllers.** Bluetooth itself works: Cliff paired audio during the
   headphone-jack work in the early days (not written down at the time; recorded here
   2026-09-13). Controllers were never tried. Needed for the dock setup. Test a
   controller pairing and InputPlumber's handling of it first.
5. **Containerised build.** Cliff (2026-09-13): "a job for Docker or some other container
   system to create a build jail"; people will ask why they need to set up binfmt by hand.
   ROCKNIX builds in Docker, Armada is a bootc image built with buildx+qemu. A Dockerfile
   with the host tools (parted, gptfdisk, dosfstools, e2fsprogs, zstd, rsync, kernel
   toolchain) plus `docker run --privileged` for loop/mount/chroot would make the README's
   requirements one line. The qemu-user binfmt registration still has to exist on the
   host kernel (that is what `tonistiigi/binfmt --install arm64` does). Moderate job: the
   harness assumes host paths and root. After release.
6. Backlog, no plan: Waydroid (docs/waydroid.md is inherited from pocknix; not in the
   image). Decided 2026-09-13: not worth it for emulation, since Waydroid renders through
   the host Mesa and gains nothing over native emulators (PPSSPP is already in the image;
   the RP5's Adreno 650 has mature Turnip support). Only use case left is Android-only
   apps, and real Android is one boot-menu choice away. Also backlog: an in-Game-Mode
   installer for emulators and Decky plugins (what Armada's "store" is; it sells nothing).

## Coexistence with ArmadaOS and ROCKNIX (Cliff, 2026-09-14) - before release

Cliff: the first people we pitch to already run ArmadaOS; Reddit will want to try both.
Done in the repo (docs/plan-2026-09-14-armada-coexistence.md): Replace mode in the installer
and GUI (take over an existing Linux install, Android untouched), the ROCKNIX/Armada backup
layout and a release catalog in the stock-bootloader tool, an INSTALL.md section. Needs the
device: the six tests in that plan, in particular which boot menu setting boots our card next
to an internal Armada, and whether Holodor runs under ABL 1.1.8 (then bump our kit to 1.1.8).
Triple boot (Android + Armada + Holodor internal) is blocked on what the closed ABL does with
two internal boot partitions; options are in the plan.

## Phase 8 - Feature parity with Android, and the next devices (Cliff, 2026-10-14)

Prompted by a user's question ("can Holodor replace Android without losing TDP control, clock
control, fan curves, OLED protection, charge separation?") and the 10-13/14 session. Status on
2026-10-14: fan curves and CPU/GPU caps (four power modes) are at parity, Bluetooth audio works
(Odin 3, tested early), the rest below is missing.

Proposed for the RP5 release (the AMOLED is the one thing a later update cannot repair):
- [ ] **OLED burn-in protection.** Dim after a few minutes of no input, screen off after a longer
      idle, both in game mode and in Desktop Mode; idle suspend already covers the long tail. The
      RP5 panel exposes /sys/class/backlight/ae94000.dsi.0 (0..4095) on both screen revisions.
      Check first whether Steam's own "dim after inactivity" does anything on our build (its
      config carries no such keys today); otherwise a small input-idle daemon in bsp-common.

Right after the RP5 audio + docks are clean (Cliff 2026-10-14):
- [ ] **Odin 3 GPU at half speed with ACD** (public issue #3, WhiteEagle-12, 2026-10-05; Cliff
      replied 10-14). Every step from 734 MHz up delivers exactly half its throughput with the
      stock `qcom,opp-acd-level` table; removing the levels restores full speed. Reproduce on our
      Odin 3 on the rig (devfreq pin, ALU-bound Vulkan compute, 1100 vs 660 MHz), then root-cause
      the GMU level mapping and write our own fix; a ~95 C passive trip on the GPU cooling device
      goes in either way (101 C within two minutes at real full speed). `msm.disable_acd=1` is
      the A/B switch. ROCKNIX and Armada ship the same table.

After the RP5 release:
- [ ] **True deep sleep better than Android (all platforms: SM8250, SM8550, SM8750).**
      - *Peripheral + clock hygiene (`kernel 56` on RP5):* Power off `vreg_mcu_3v3` (MCU, 4 Hall-effect stick/trigger sensors, and 2 HTR3212 RGB controllers on GPIO 3/5/6/109/111) across `s2idle` just like Android's `mcu_power_control` (`fb_notifier_callback`), stop the `pwm-fan` tach timer and disable the 5V fan boost converter (`vreg_fan_pwr`, GPIO 7) across suspend even when the fan was already at 0% PWM, fix the `ufs-qcom` lane-clock double-enable leak that held `bi_tcxo` (`ref_clk`) on across runtime suspend, hold UFS clock-gating across system PM, and let `WCD938x` + LPASS macros runtime-suspend cleanly with `MBHC` jack wake intact.
      - *Beat Android's standby floor:* Stock Android on the RP5 suffers periodic wake ticks (`qcom_rx_wakelock` / `msm_hs_wakeup` / `alarmtimer` every hour). With Wi-Fi/BT cleanly stopped or moved to silent WOWLAN and zero periodic Android userland alarms, Linux can eliminate the hourly wake spikes entirely.
      - *SoC-level `aosd` / `cxsd` / `ddr` sleep across all three SoCs:* Drive `bi_tcxo` (`gcc_XO`) votes to zero in `s2idle`, verify RPMh `SLEEP` TCS firing on SM8250/SM8550/SM8750, and isolate the PCIe RC / `ath11k` D3cold vs. link-retention path so AOSS enters true XO shutdown (`aosd > 0`, `cxsd > 0`).
- [ ] **Track Kettle Linux (`github.com/kettlelinux/kettlelinux`) as a peer upstream alongside ROCKNIX, pocknix-os, and ArmadaOS.** Kettle Linux's `sm8250` (`6.19`) and `sm8550` (`6.18`) patch stacks carry clean, surgical mainline fixes (`ufs-qcom` lane-clock guard, UFS clock-gating across PM, `pwm-fan` suspend timer quiesce, `retroid.c` split-frame reassembly, `drm/msm` `perf_now` debugfs load export, LPASS macro PM force-suspend). Sweep Kettle Linux regularly alongside ROCKNIX and pocknix-os.
- [ ] **Charge limit on the RP5 + bypass charging ("charge separation") on both.** Pocknix Control's
      80/85/90/100 limit writes charge_control_end_threshold, which only the Odin 3 battmgr
      exposes; the RP5 pm8150b driver needs the thresholds (our 0722 charger patch is the place).
      Bypass = run from the charger with the battery idle: Odin battmgr constant_charge_current=0
      (upstream sweep 09-27), RP5 PM8150B charging-enable bit. One toggle in the Power tab.
- [ ] **Bluetooth audio on the RP5**: never tried on any build (works on the Odin 3). One headset test.
- [ ] **Shared ROM card between Android and Holodor** (internal dual boot, SD slot free). The card is
      Android *portable* storage = exFAT (adoptable storage is encrypted and invisible to Linux);
      both kernels have exFAT built in; our pocknix-sdcard-automount mounts ext4 only (SteamOS
      lineage) and needs exFAT with the deck uid/gid. ES-DE runs on both OSes with the same
      ROMs/<system> tree: share ROMs + BIOS (+ scraped media), saves optional, states never, one
      partition, FAT32 out (4 GB limit). Docs page for users.
- [ ] **Retroid Pocket 6 / Snapdragon 8 Gen 2 port** (Cliff: "use everything we have learned ...
      as quickly and efficiently as possible"). devices/sm8550 is a dormant family target (RP6 +
      Odin 2 line, untouched since 07-16); mainline sm8550 support is mature; the MaSieS image
      carries an RP6 dts adapted from LineageOS. Day one = Android ground truth before any Linux
      fix (live device tree, mixer paths, charger and Type-C facts, speaker/jack measured on the
      mic, dock video both orientations), then diff against ROCKNIX and Kettle Linux on the same board, one fix per
      cause, verified at the register / HID / mic.
- [ ] Backlog: per-game power mode (the four modes are global today; game tweaks exist for FEX,
      audio and frame insertion, not power).
