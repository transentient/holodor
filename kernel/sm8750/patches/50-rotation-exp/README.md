# 50-rotation-exp — DPU hardware (inline) rotation, OPTIONAL experiment series

Not applied by default. `scripts/build-kernel.sh` skips this dir (it carries an
`OPTIONAL` marker) unless `HOLODOR_KERNEL_EXTRA_SERIES` names it:

    HOLODOR_KERNEL_EXTRA_SERIES="50-rotation-exp" make kernel

Both patches are verbatim ROCKNIX (tiopex, PR #3299 / #3340) with a Holodor
provenance header; Armada carries the same content as its combined 0066
(1670abf, shipped in ArmadaOS 20260915 as "improved game performance due to
hardware display rotation"). Applied AFTER 10/20/30/40 (numeric order), verified
2026-09-20 at fuzz 0 with no offsets on top of the full current stack.

| file | origin | what |
|---|---|---|
| `0013-drm-msm-dpu-fix-inline-rotation.patch` | ROCKNIX `packages/linux/patches/7.2/0013` (180057b, 2026-09-17) | generic dpu_plane/dpu_rm fixes: CW/CCW XOR on rot90, pre-rotated HEIGHT check, keep QSEED for 1:1 RGB when rotating, test_bit SSPP reservation |
| `0068-drm-msm-dpu-enable-sm8750-inline-rotation.patch` | ROCKNIX `devices/SM8750/patches/linux/0068` (ec3d53baac 2026-09-11, reduced by 180057b) | SM8750 catalog: VIG SSPPs get `DPU_SSPP_INLINE_ROTATION` + rotation cfg (rot_maxheight 1088, UBWC RGB/2101010/NV12/P010 formats) |

Deliberately NOT carried: ROCKNIX `0067-drm-msm-dpu-enable-qseed-detail-enhancer`
(same PR). Armada dropped it from their series a day later (bdaac16, 2026-09-12:
hardcoded sharpening curves, untuned; writes DE_LPF_BLEND which QSEED 3.0 lacks).

The kernel half is inert on its own: the DPU planes merely start advertising
`rotate-90/270`. Our shipped gamescope (Valve 4286887 + ROCKNIX 0005 rotation
shader) pins the plane `rotation` property to ROTATE_0 while the shader is on, so
nothing changes until the userspace half (`packages/gamescope-next`, Valve
3.16.29 = 8f21264, no shader patch) and the launcher switch (`POCKNIX_ROTATION=hw`) are in
place. Full write-up, A/B protocol, rollback and risks:
`docs/rotation-experiment-2026-09-20.md`.

Promotion rule (if the A/B wins): move both files into `20-sm8750/` under their
ROCKNIX numbers (0068; 0013 renumbered into the 20-series range since it is a
common ROCKNIX patch — e.g. 0069 — and note the origin in the header), delete
this dir, drop the env switch, bump linux-pocknix-sm8750 pkgrel, update
PATCHES.md's sm8750 row.
