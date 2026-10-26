# Inquisitor review — sleep/battery work, 2026-09-05

Independent adversarial review for Cliff. Sources: HANDOFF.md (CURRENT STATE, findings #5/#6, 08-18, 08-29 blocks), docs/plan-2026-09-04.md, the kernel patch dirs, bsp-common hooks, the four measurement scripts, and the public Armada / ROCKNIX / pocknix trees (fetched today). The device was unreachable (asleep or off), so no live reads. "Verified" = I read it in the repo/log/upstream; "judgement" = mine.

## 1. Verdict

The strategic direction is right: s2idle as the shipped sleep state is correct, and the wake-side bugs are correctly root-caused. The last three days on charging were wrong in method, not in goal: the agent built a five-slice "bounded-window" model on `charge_counter` deltas from a gauge its own log declares untrustworthy, ran a plugged deep suspend it had documented as a wedge, and queued more hours of the same measurement — while never checking that **our own kernel carries the exact patch Armada replaced on 08-13 to fix "charging not starting when plugged in during s2idle sleep" on this SoC**. That is not a plan stuck in a loop; it is a loop with plan-shaped commentary. The shortest path is one kernel patch swap and three small userspace fixes, all already known, not more probes.

## 2. What is real and load-bearing

Verified facts (hardware-read, in the log):
- **s2idle beats deep on drain, same-method A/B** (31 mA vs 150–215 mA; commit 6c3fa42, 319474c). The *ratio* is real. The *absolute* 31 mA is gauge-derived and unconfirmed by an independent method (see §3).
- **aosd/cxsd/ddr = 0 on every kernel** (qcom_stats, HANDOFF 08-29). Real, and independently corroborated: ROCKNIX PR 3126 found the same on SM8550 (`3d6a000.gmu: no driver bound` blocks clock sync_state). docs/aoss-deep-sleep-research.md is good work.
- **Armada patch 1005 (rsinput MCU quiesce) saves ~380 mA asleep** — clean bisect (HANDOFF 08-28→29).
- **Plugged s2idle sleep barely charges**: two all-day sleeps gained 8% and 11%; awake charges 4–5 A (HANDOFF #5). This is the user-visible fact and it is real.
- **Wifi sulk = post-resume roam → WCN7860 fw assert** (kernel log, HANDOFF #4). **pocknix-wifi-heal has never run** (`setsid &` in `wifi-sleep-post:9`, killed with the hook cgroup). Both real; fix is one line plus an iwd key verified in source.
- **Two-presses-to-wake = wake-grace inhibitor races logind** (`Failed to inhibit: ... already running`, HANDOFF #6). Real, 2/12 wakes.
- **Brownout at 3%**: upower `Action=2 CriticalPowerAction=HybridSleep` with no swap. Real.
- Charger fw re-asserts the 80/70 cap after boot; `charge_counter` is a rewritten estimate (rose +217 mAh during a *discharging* sleep). Real — and important below.
- powerd brightness-floor restore fired once in the journal. Real. Everything else in the powerd diff (press-on-dim, grace-cancel) is unobserved.

Agent interpretations, not facts: "charging runs ~25–30 min then the firmware pauses"; "fw treats the quiet device-mode USB link as bus-suspend"; "AP does service the glink link in s2idle"; "0.4 %/h overnight".

## 3. Where it went wrong

**a. The 30-minute-pause model rests on the number the same block says not to trust.** The slice table (HANDOFF #5) is `charge_counter` deltas taken 09-04 during a gauge relearn; the "WRONG THIS SESSION" list 60 lines lower says `charge_counter` is battmgr's estimate and gets rewritten. The series is not even monotone: 40 min → 614 mAh, 80 min → 280 mAh. The only physical datum is one wake-instant `current_now ≈ -7 mA` after the 160-min slice; the 60-min state1-off slice showed **+167 mA at wake — i.e. not paused**. n=1 for the pause, n=1 against it. ROCKNIX's xiaodoudou hit the identical trap on SM8550 and retracted a week of numbers: "`charge_counter` and `capacity` turn out to be the same number rescaled … resyncs the moment a charger goes in, once by 1.58 Ah" (PR 3126, 08-10). Judgement: "pause after 30 min" is unproven; "plugged s2idle averages ~120–190 mA net instead of amps" is proven and is all we need.

**b. Not looking where the answer was.** Verified in upstream today:
- Armada issue #143 "Odin 3 not charging in standby/sleep" (07-22, same hardware).
- Armada `armada-packages` 973ced69 (08-13): *"Fix charging not starting when plugged in during s2idle sleep."* It **deletes** `0504-wakeup-qcom-ipcc-remove-IRQF-NO-SUSPEND.patch` and replaces it with `0504-mailbox-qcom-ipcc-mask-summary-irq-for-suspend-to-ram.patch`, commit text: the blanket removal "also silenced the doorbell during suspend-to-idle, where a live doorbell lets the charger firmware complete a cable attach with the AP asleep."
- **We carry the deleted patch**: `kernel/sm8750/patches/20-sm8750/0504-wakeup-qcom-ipcc-remove-IRQF-NO-SUSPEND.patch` (since the 07-28 kickoff). Under s2idle the PM core masks that IRQ exactly like under deep, so the battmgr doorbell is deaf for the whole sleep. Deep charged fine because the AP is power-collapsed and the fw takes its off-mode path; s2idle leaves the AP alive-but-deaf. Judgement: this is the single most credible cause, and it costs one patch swap to test. The agent wrote "AP DOES service the link in s2idle" (HANDOFF:135) without grepping its own patch dir for `ipcc`, and had "armada 0504-ipcc … staged-not-applied" in its notes since 08-19 (HANDOFF:1370).
- Armada 0656c6f9 (08-21): dwc3 `power/control=auto` for s2idle (drops the 1 GB/s USB→DDR vote). The plan's candidate (i) proposes the *opposite* (`=on`), untested either way. Armada 47ecdee7 (09-04): every device defaults to native s2idle.
The 09-01 "upstream sweep" was scoped 08-24→08-31 and so missed 08-13 and 08-21 by construction.

**c. Ran a known-wedge path unattended.** The 09-04 plugged `deep 40` A/B: the 0519 patch text in our own tree describes the exact failure, and the runner note says "keep the rescue SD handy the first time." Result: no resume, hot SoC, forced power-off, zero data. Whether 0519 covers Cliff's charger could have been answered from the `usb_role` sysfs read that was already in the probe CSV.

**d. Measurement theater.** Three days produced six measurement artefacts (48-chargeprobe, telemetry, drainlog, series runner, experiments runner, fusor follower) and zero shipped fixes. Two runner failures (rtcwake args lost to quoting; follower polling over a wifi link that is down for the first seconds after wake) are not recorded anywhere in HANDOFF — Cliff's babysitting is the only record. The state1-off result was declared "inconclusive" and the response was to queue two more hours of the same instrument.

**e. Small known fixes left unapplied while probing continued.** Grace race (3 lines, known 09-04 12:53), wifi-heal launcher (1 line, known 09-03), upower brownout policy (2 keys, known 09-02), powerd prototype still uncommitted (live device ≠ repo, which violates Cliff's parity rule).

**f. Scope drift during a "sleep/battery" focus**: RP5 recon, turnip landscape doc, mesa-next-6 staging, Vulkaiser, kernel-24 OLED backlight (HANDOFF "What we did 08-31→09-03").

## 4. s2idle vs deep — which to ship

Ship s2idle. Verified: deep on this port never reaches AOSS collapse either (aosd=0), so it only buys 5× worse drain plus the plugged wedge, and 0519 provably does not cover Cliff's charger. Neighbours: Armada (same Odin 3) fixed charging *under s2idle* on 08-13 and made s2idle the default on 09-04. ROCKNIX SM8550 (PR 3126, open) chose deep and charges in sleep — at 4–5 %/h drain, which they admit. pocknix pins s2idle and ships dwc3 autosuspend. postmarketOS on sm8x50: no published suspend-charging work that I could find. What I don't know: whether Armada's fix also cures a "cable already attached, charging stops later" case rather than only cable-attach-while-asleep; the mechanism (deaf doorbell) covers both, but only the test settles it.

## 5. Shortest credible path

1. **Kernel-25 = swap 0504.** Drop `20-sm8750/0504-wakeup-qcom-ipcc-remove-IRQF-NO-SUSPEND.patch`, add Armada's `0504-mailbox-qcom-ipcc-mask-summary-irq-for-suspend-to-ram.patch` (already `qcom,sm8750-ipcc`-scoped). Consider Armada's `60-armada-usb-autosuspend.rules` in the same bump. **Done when:** one plugged 60-min s2idle nap from ≤70% shows `current_now` still negative-and-large in the existing 48-chargeprobe wake loop *and* a plugged overnight reaches the 100/95 threshold. Cliff cost: install the pkg over ssh (agent can), leave it plugged one night. s2idle only, no wedge risk beyond any kernel change; rescue SD in the drawer as usual.
2. **bsp-common-17, one bump, all of:** (a) `wake-grace-post`: retry the inhibit ≤20×0.1 s or delay it 1 s (`systemd-run --on-active=1`); (b) `wifi-sleep-post`: `systemd-run --collect` + 90 s watch + `nmcli connection up` first; (c) iwd `[Scan] DisableRoamingScan=true` + 5 GHz rank bias; (d) upower `PercentageAction=5`, `CriticalPowerAction=PowerOff`, powerd refuses suspend <5%; (e) commit the powerd prototype; (f) pocknix-charge-full re-applies on power_supply udev events; (g) delete 48-chargeprobe/49-drainlog from the image. **Done when:** 20 wake cycles (half mid-game, some plugged) = one press, controls in 3 s, wifi in 10 s, no Steam dialogs. Cliff cost: ~1 h of pressing the button.
3. **Only if #1 fails:** plugged-in RTC self-wake every 25 min with a stay-dark re-suspend path (plan Point 1 stopgap). Residual behaviour: a faint ~2 s wake blip every 25 min while plugged, charge reaches 100% by morning. Acceptable to ship; it is what "good enough" looks like.
4. **Dead controls after resume mid-game:** one instrumented reproduction (`udevadm monitor` + Steam controller.txt around a suspend), not a framework. Cliff cost: two reproductions.
5. Gauge: nothing to build. Finish the relearn cycle Cliff is already doing; judge % against voltage, never against `charge_counter`.

Plan-2026-09-04 dispositions: **KILL** Point 1 "real-fix" knobs (i)/(iii) and the knee test as designed (charge_counter as the metric, hour-long slices). **KILL** further `chargeprobe-experiments.sh` runs. **REORDER** the stopgap self-wake behind item 1 above. **KEEP** brownout policy, grace fix, wifi pair, commit-powerd, controls instrumentation, 20-cycle ceremony. Everything in Points 5–8 waits until items 1–2 ship.

## 6. The previous agent should stop

- Building another measurement script before shipping the fixes it already has.
- Treating `charge_counter`/`capacity` as data; use `current_now` at the wake instant and voltage endpoints only.
- Running anything unattended on a path its own tree documents as a wedge.
- Sweeping upstream by date window; sweep by *symptom* (grep sibling trees and issues for the bug at hand) and grep our own patch dir before theorising about kernel behaviour.
- Leaving known one-line fixes unapplied and the live device diverged from the repo.
- Widening scope (graphics, RP5, docs) inside a sleep/battery focus.
