# AOSS deep sleep on SM8750 — research findings (2026-08-29)

Context: coulomb-measured suspend floor of ~150–215 mA on the Odin 3 across every
kernel and even with all userspace stopped; /sys/kernel/debug/qcom_stats shows
aosd/cxsd/ddr Count 0 across verified S3 suspends. Research agent swept mainline,
ROCKNIX/ArmadaOS/batocera/pocknix/thorch, and mobile-Linux ecosystems. Verdict:
**nobody has demonstrated aosd/cxsd on mainline sm8550/8650/8750 consumer devices
yet** — we are at the frontier, not behind it.

## The mechanism (verified)

AOSS collapse requires the APSS RSC to flush SLEEP/WAKE TCS votes to RPMh, and
every vote in the sleep set must permit the state. On mainline this flush happens
in exactly one place: `rpmh_rsc_pd_callback()` (drivers/soc/qcom/rpmh-rsc.c), a
genpd notifier on the PSCI cluster/system power domain. Two gates:

1. **PSCI OSI mode is mandatory.** If OSI doesn't enable, the CPU power domains
   get GENPD_FLAG_ALWAYS_ON, the notifier never fires, sleep sets are never
   written — aosd stays 0 forever. (Precedent: sc7180 Acer Aspire 1 began
   accumulating ddr/cxsd durations once the OSI config was fixed — so mainline
   CAN reach chip sleep on Qualcomm consumer firmware.)
2. **The flush path is exercised by cpuidle (s2idle), NOT by "deep" (S3).** Our
   "PM: suspend entry (deep)" = PSCI SYSTEM_SUSPEND, a firmware path that never
   runs the cluster-idle machinery. sm8750.dtsi even wires `system_pd` with a
   "domain-sleep-0" state — enterable only via s2idle. pocknix (Odin 2/sm8550)
   pins s2idle outright ("deep wedges with its rail constraints").

Additional vote-holders that block cxsd even when the flush runs: any prepared
`bi_tcxo` clock consumer votes XO ON in the sleep set; rpmhpd + interconnect
clamp ALL rails/bandwidth to max until every DT consumer probes (one permanently
deferred probe = max rails forever — a candidate for our exact floor); mainline
qcom-rpmh-regulator only ever votes ACTIVE state, so every enabled rail stays at
full power through suspend.

The "unbooted modem/slpi hold bootloader votes" theory: **unsupported by any
source** — no project boots subsystems to release votes; don't chase it.

## What other projects ship (none fix aosd; all mitigate)

- **pocknix/thorch (sm8550)** — the deliberate stack: pin `mem_sleep=s2idle`;
  re-enable cpu0 cpuidle state1 only during the suspend window; USB autosuspend
  (drops USB→DDR icc vote); **Luke Johnson's RPMh regulator SLEEP/WAKE-set patch
  pair** (pocknix 1046/1047 = thorch 0218/0219) + board `regulator-state-mem`
  DTS (thorch 0006) — the one shipped mitigation that measurably lowers rail
  power. Port candidates for us.
- **ArmadaOS** — `armada-sleep-debug` (qcom_stats before/after deltas; their own
  text: "deltas of 0 ... mean the SoC rails never powered down"); ipcc/tsens irq
  masks; PCIe suspend-OPP as the DDR-contract floor.
- **batocera.pocket** — uniquely carries the in-review **rpmh read-back series**
  (qcs6490 patches 0037/0038; lore v3 2026-04) = the only tool for enumerating
  bootloader-stage votes.
- **ROCKNIX** — CONFIG_QCOM_STATS=y, irq-mask patches, nothing aosd-related.
- postmarketOS on sm8550/8650: no published suspend-power work at all.

Steam Frame note: the "deep sleep not released for Linux yet" quote could not be
sourced to a primary interview — treat as unsourced but consistent.

## Attack ladder for the Odin 3 (ordered by evidence strength)

1. `dmesg | grep -i osi` — if OSI didn't enable, that single flag decides
   everything; fix that first.
2. **s2idle soak**: boot with `mem_sleep_default=s2idle`, suspend, read
   qcom_stats deltas + coulomb. The cheapest possibly-huge experiment we have.
   (Caveat: our suspend stack — 0513 geni mask, 0519 UCSI, wake sources — was
   tuned on deep; expect a validation pass.)
3. Verify s2idle reaches the deepest cpuidle/domain states (s2idle/usage
   counters; no boot-time cpuidle disables in the way).
4. Vote hygiene: clk_summary for prepared bi_tcxo consumers; confirm rpmhpd/icc
   sync_state fired (check deferred_probe list — one stuck probe = max rails).
5. Port Luke Johnson regulator SLEEP-set pair + write our `regulator-state-mem`
   DTS (crib thorch 0006 — same AYN gamepad-MCU rail layout family).
6. Carry the rpmh read-back series for bootloader-vote visibility.
7. Converged small stuff: USB autosuspend, PCIe suspend-OPP, adsp audio-path
   check before suspend (a left-open audio path blocks adsp sleep).

Full agent report with all links/commits lives in the 2026-08-29 session; key
sources: armada-sleep-debug, armada-packages PATCHES.md, pocknix 1046/1047,
thorch 0006/0218/0219, batocera qcs6490 0037/0038, sc7180 OSI patch (patchew),
SDM845 low-power RFC, rpmh read-back series (lore).
