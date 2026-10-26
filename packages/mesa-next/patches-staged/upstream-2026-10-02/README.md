# Staged from the 2026-10-02 upstream sweep: NOT applied

Context: `docs/upstream-sweep-2026-10-02.md`.

- `mr19316-*`: mesa !19316 "Clear UBWC flags buffer on transition from UNDEFINED" (2 commits, 2022,
  needs a rebase). Describes an A650 UBWC whole-machine hang: candidate for the RP5 DXVK freeze.
- `rx-0001..0003-*`: ROCKNIX PR #3388 Turnip autotune (binning pass in RP duration, stable RP hash,
  calibrated bandwidth model). rx-0003 says "Assisted by: Gemini". Try the env knobs on the current
  pin first (TU_AUTOTUNE_ALGO / TU_AUTOTUNE_FLAGS).
