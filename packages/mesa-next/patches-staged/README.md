# Parked mesa-next patches (not applied)

Neither patch is in the shipped build. They rode mesa-next pkgrel 6, which lost the
2026-09-06 Cyberpunk A/B (-3.2% against pkgrel 5) and was never shipped.

- 0001 (a830 has_fs_tex_prefetch=False): measured free the same night with the runtime
  override `FD_DEV_FEATURES=has_fs_tex_prefetch=0` (22.08 vs 22.06 baseline), so it is
  neither the regression nor a gain. No observed bug behind it. Use the env override if
  it ever needs testing again; no rebuild required.
- 0002 (a8xx has_64b_image_atomics=False): UE5/VKD3D hang hedge, no reproduced bug on
  this device. Untested.

Details: docs/cyberpunk-bench-plan.md, docs/turnip-a830-landscape.md.
