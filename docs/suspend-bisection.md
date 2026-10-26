# Suspend wedge bisection (pm_test) — procedure

The intermittent no-wake wedge (journal always ends at `PM: suspend entry (deep)`;
3 occurrences as of 2026-08-07, survived the PCIe-GDSC patch) dies somewhere the
journal cannot reach. `pm_test` fakes suspend at progressively deeper stages so we
can find WHICH stage kills it — each stage waits 5s then resumes automatically,
no power button involved.

Run over SSH with Cliff watching the panel. At each stage, repeat ~5x (the wedge
is intermittent — a single pass proves little):

    for mode in freezer devices platform processors core; do
      echo $mode > /sys/power/pm_test
      for i in 1 2 3 4 5; do systemctl suspend; sleep 20; done
      journalctl -b --no-pager | tail -5   # confirm clean exit each round
    done
    echo none > /sys/power/pm_test         # ALWAYS restore

- Wedge during `devices`   -> a driver's suspend/resume callback (likely candidates:
  msm/GPU, ath12k leftovers, USB) — bisect further by unbinding suspects first.
- Wedge during `platform`  -> PSCI/AOSS/TZ firmware territory (harder; compare
  ROCKNIX/armada kernel deltas, esp. their 7.1.5 bumps).
- Wedge only in REAL suspend (all pm_test stages clean) -> resume-side power-on
  failure; try `pm_print_times=1` + `no_console_suspend` for more breadcrumbs,
  and consider the SDAM breadcrumb hook's post-boot readout.

Note: wifi-off hook + inputplumber hook still run for real `systemctl suspend`
(system-sleep dispatcher) — that's fine, it matches the real path.
