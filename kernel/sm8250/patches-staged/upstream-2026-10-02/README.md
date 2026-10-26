# Staged from the 2026-10-02 upstream sweep: NOT applied

Context: `docs/upstream-sweep-2026-10-02.md`.

- `armada-0619-*`: msm submitqueue priority (Armada PR #574); same patch as the sm8750 copy.
- `armada-0505a-*`: arm64 unaligned atomics, Load128 store-exclusive (Armada #582). Armada says SM8550+
  does these in hardware, so this is RP5-only.
- `msm-next-128a0edd-*`: secondary rail in ARC votes (whole a6xx family).
- `qcom-adf55ad006-*`: upstream sm8250 PCIe WAKE# polarity fix.
