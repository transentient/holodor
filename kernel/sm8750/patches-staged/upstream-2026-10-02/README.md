# Staged from the 2026-10-02 upstream sweep: NOT applied

Parked until the headphone jack and the basic RP5 work are done. Context, risks and order:
`docs/upstream-sweep-2026-10-02.md`.

- `armada-0619-*`: msm submitqueue priority (Armada PR #574). Likely fixes issue #1 (QAM freeze).
- `msm-next-2c94d177-*`: upstream Adreno 830 support (Linux 7.4). Reference for rebasing our 0049;
  `a830-reglist-ours-vs-upstream.diff` is the register-list difference. Don't take its chip id
  (0x44050001) on its own: it has to move together with 0038's compatible and mesa >= 2061a5ee.
- `msm-next-db6a2e4a/eab0aff8/128a0edd-*`: GPU power-vote fixes (3-8 lines each). Our perfmode_bw
  (8171875) differs from upstream (10687500).
- `msm-next-bbe4401e-*` (THP for GEM), `msm-next-8eeca96a-*` (shrinker-blocking modparam): memory/stutter.
- `qcom-eec036783b-*`: upstream sm8750 WAKE# polarity fix. Ours is a one-line edit in 0046
  (`wake-gpios = <&tlmm 104 GPIO_ACTIVE_HIGH>` -> ACTIVE_LOW), not this patch.
- `qcom-f695831a-*`: sm8750 GPU clock + IOMMU nodes (7.4); reference for replacing 0038 on a 7.4 base.
