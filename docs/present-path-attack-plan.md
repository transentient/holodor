# Present-path attack plan — Cyberpunk native fps (2026-08-16)

Goal: the native ceiling is ~21 fps with the GPU pinned at 1100 MHz but only ~52% busy and
the app frametime floored at ~48 ms (docs/cyberpunk-bench-plan.md, runs G/I). That is a
present-path wait, not a horsepower limit. If the wait shrinks, the same silicon has ~30 fps
in it (≈25 ms of GPU work per frame → ~40 fps theoretical if presents were free).

This doc records what each candidate avenue actually looks like in OUR kernel and OUR
gamescope source, ranks the interventions, and defines the first experiment.

Evidence sources (collected live on the device 2026-08-16, read-only, game running):
- `/sys/kernel/debug/dri/0/state`, `/sys/kernel/debug/dri/0/crtc-0/status`, `modetest -M msm -p/-c`
- Kernel tree: `build/kernel/sm8750/linux-7.1.3` (stock 7.1.3 + `kernel/sm8750/patches`)
- Gamescope: Valve commit `4286887` + ROCKNIX patches (`packages/gamescope/PKGBUILD`),
  upstream source verified at that exact commit.

---

## The hard constraint first: the DPU command-mode timeout class

`gamescope -r 120` previously wedged the DPU command-mode pipeline — ppdone/vblank
timeouts ×118 per boot; dropping `-r` entirely = zero errors (HANDOFF.md, "Hard-won
knowledge" item 2). **Never reintroduce `-r`.**

Mechanism (provisional — reconstructed from source, not re-reproduced): `-r` enables
gamescope's refresh-switching path, `drm_set_refresh()` at
`src/Backends/DRMBackend.cpp:3307`. If `find_mode()` misses, it **generates** a CVT or
fixed mode (DRMBackend.cpp:3327-3348) and full-modesets to it (`drm_set_mode`,
DRMBackend.cpp:3272). Generated video-mode-style timings and/or repeated modesets on this
command-mode DSI panel are the plausible wedge. Whatever the exact trigger, the failure
class is clear: **modesets and non-driver modes on the command-mode pipeline**.

Rules for every experiment below:
- Prefer paths that involve **no modeset** (convars, env vars, game settings).
- If a modeset is unavoidable (60 Hz test), use only the **existing driver mode**, watch
  `dmesg -w | grep -Ei "ppdone|vblank.*time.*out|timeout"` during the whole session, and
  have a one-step revert (remove flag, reboot).
- Note: `/sys/kernel/debug/dri/0/kms` already carries a "dpu devcoredump" register
  snapshot header — after any experiment, check whether a NEW devcoredump appeared
  (`ls /sys/class/devcoredump/ 2>/dev/null`, dmesg timestamps).

---

## Avenue 1 — DPU hardware rotation: DEAD (with proof, not just "missing")

Device evidence: every DPU plane advertises `rotation: rotate-0=0x1 rotate-180=0x4
reflect-x=0x10 reflect-y=0x20` — **no rotate-90/270** (`modetest -M msm -p`). Current
scanout: one plane, XR30 1080x1920, modifier `0x500000000000001` (QCOM_COMPRESSED/UBWC),
`rotation=1`, sspp_8, dual-mixer 540x1920 split (`crtc-0/status`).

Kernel source (all paths under `build/kernel/sm8750/linux-7.1.3/drivers/gpu/drm/msm/disp/dpu1/`):
- `dpu_plane.c:1862-1866` — the plane only gains `DRM_MODE_ROTATE_MASK` when the SSPP has
  `DPU_SSPP_INLINE_ROTATION`.
- `catalog/dpu_12_0_sm8750.h:58-125` — every sm8750 SSPP uses `VIG_SDM845_MASK_SDMA` /
  `DMA_SDM845_MASK_SDMA`. Neither includes `DPU_SSPP_INLINE_ROTATION`; the only mask that
  does is `VIG_SC7280_MASK` (`dpu_hw_catalog.c:56-57`).
- Even where inline rotation exists, `dpu_plane_check_inline_rotation()`
  (`dpu_plane.c:690-720`) requires: UBWC format, format in `rot_format_list`, and
  pre-rotated height ≤ `rot_maxheight`. The only format list in the tree is
  `rotation_v2_formats = { DRM_FORMAT_NV12 }` (`dpu_hw_catalog.c:188-191`) and
  `rot_maxheight = 1088` (`dpu_hw_catalog.c:306-309`). `dpu_rm.c:820` additionally gates
  SSPP assignment on the feature bit.

Conclusion: a catalog hack could not save us. Gamescope's composite is 1080x1920 XR30 —
RGB (not NV12) and 1920 wide pre-rotation (> 1088). DPU inline rotation is a UBWC-NV12
video-decode feature, not a compositor rotation engine. **Do not spend kernel effort here.**
This also independently confirms the PKGBUILD note: vanilla gamescope's plane-rotation
attempt can never work on msm (upstream gamescope issues #1883/#819).

## Avenue 2 — gamescope's rotation path: the shader is NOT the tax; the forced composite is

Read `packages/gamescope/0005-feature-add-rotation-shader-for-rotating-output.patch`
against base `4286887`:

- `--use-rotation-shader` does **not** add a separate full-screen pass. It adds a
  `get_rotated_dst_coord()` helper (patch, `src/shaders/descriptor_set.h` hunk) and every
  composite shader (blit/rcas/blur/nv12) simply **writes its output transposed** in the
  same single dispatch. The scanout images are allocated physical-portrait 1080x1920
  (patch, `vulkan_make_output_images` hunk) — matches the live fb on the device.
- The real costs are:
  1. `bNeedsFullComposite |= rotationShaderOrientation != GAMESCOPE_PANEL_ORIENTATION_0;`
     (patch, steamcompmgr hunk) — **direct scanout is permanently impossible**; every frame
     composites, even a bare fullscreen game with no overlay.
  2. Transposed `imageStore` pattern = poor write locality (minor; see below).
- The DRM plane `rotation` property is set to ROTATE_0 when the shader is on (patch,
  `drm_prepare_liftoff` hunk), which is exactly what the kernel accepts.

Two prior measurements bound the size of this tax:
- Patch 0007 (composite-rotation, PR #2228) vs 0005 was **A/B'd fps-neutral**
  (PKGBUILD header) → the GPU cost of rotating-while-compositing is not the binding
  constraint.
- GPU is only ~52% busy at max clock → composite cost fits easily; the frame time is
  dominated by *waiting*, not shading.

So the prize is not "make the shader cheaper", it is "shrink the present/pacing chain that
the forced composite drags in". That chain (base `4286887`):
game commits buffer → steamcompmgr latches at its scheduled draw point
(`src/vblankmanager.cpp:107-155`: draw time = rolling-max draw time + redzone, default
`kDefaultVBlankRedZone = 1.65ms`, `vblankmanager.hpp:35`, anchored to vblank/TE) →
composite dispatch → atomic commit → ppdone/TE latch → buffer release / frame callback →
game's blocked present returns. At 120 Hz each vblank-anchored hop is ≤8.3 ms; two-to-three
hops plus FIFO-depth blocking on top of ~25 ms of game GPU work lands right at the observed
~48 ms floor. **(Provisional decomposition — instrumentation below decides.)**

## Avenue 3 — panel orientation / pre-rotated rendering: dead for Cyberpunk

- DT: `kernel/sm8750/patches/20-sm8750/0047-arm64-dts-qcom-Add-AYN-Odin3.patch:262` sets
  `rotation = <90>` on `&display_panel` (chipone,icna3520). The panel driver
  (`drivers/gpu/drm/panel/panel-chipone-icna35xx.c:523` via
  `of_drm_get_panel_orientation`, exposed at `:419`) publishes the standard panel
  orientation property; gamescope is additionally launched with
  `--force-orientation right`, which matches.
- The panel cannot be "exposed landscape natively": scan direction is a physical property
  of the panel/DDIC; MADCTL-style flips give 180°/mirror, never a 90° transpose. Removing
  `rotation` from DT would only make software *unaware* it is rotated.
- Vulkan pre-rotation (Android-style `VK_SURFACE_TRANSFORM_ROTATE_90`, which Qualcomm
  recommends so the *game* renders pre-rotated and nobody rotates) requires the app to
  handle `preTransform`. Cyberpunk is a Windows title under FEX+Proton/DXVK — DXVK does
  not implement surface pre-transform, and the gamescope WSI layer doesn't expose one.
  **Dead for Proton titles.** (Footnote: native apps that can render portrait themselves —
  RetroArch rotation, emulators — could in principle skip the rotation and even regain
  direct scanout, but that requires gamescope to allow scanout again, i.e. lifting the
  `bNeedsFullComposite` force for pre-rotated buffers. Out of scope for Cyberpunk.)

## Avenue 4 — cheaper present: the actual lever set

1. **Game present mode (FIFO vs mailbox).** If Cyberpunk runs with VSync on, its present
   blocks on the whole chain above every frame. `UserSettings.json` on the device has a
   `"VSync"` key (path below); the value was NOT read before the device went offline.
   VSync off → mailbox-style present through the gamescope WSI layer → the game stops
   blocking and gamescope latches the freshest frame. Zero risk, potentially the entire
   win. This must be checked first — it would also explain why `--immediate-flips`
   (a KMS-side change that doesn't unblock a FIFO client) helped nothing.
2. **Pacing/scheduling in gamescope.** The base bump fe78bc6→4286887 was made precisely
   for upstream's present/FIFO frame-callback rework (PKGBUILD header). Follow-on options,
   all userspace, none touching the DPU danger class: tune the vblank draw scheduling
   (`vblankmanager.cpp`), or prototype compositing immediately when a new game buffer
   arrives instead of waiting for the next vblank-anchored draw point. Requires the
   instrumentation results first.
3. **Refresh cap without modeset:** `--framerate-limit` exists on this base
   (`src/steamcompmgr.cpp:5834-5838`) and is implemented as a **vblank divisor — no
   modeset, no `-r` machinery**. It cannot raise 21 fps, but `--framerate-limit 24` (120/5)
   is a safe tool to test whether *stable* cadence feels better, and a probe for pacing
   theories.
4. **60 Hz panel mode:** the driver already exposes a real 60 Hz command-mode timing
   (`modetest -c`: mode #1 `1080x1920@60`, vtot 3955 vs 1977 — extended vertical
   blanking). Halving TE rate does NOT halve composite work (composite already runs at
   game rate, ~21/s, measured earlier: ring-0 submits == present rate). It *doubles* the
   granularity of every vblank-anchored hop (8.3→16.7 ms), so for a wait-chain theory it
   is likely neutral-to-worse. Park it unless instrumentation says the wait is
   TE-quantized in a way 60 Hz helps. It is also the only experiment in the modeset risk
   class.
5. **Adaptive sync:** `cv_adaptive_sync` exists (`steamcompmgr.cpp:295`) but the DSI panel
   advertises no VRR — not applicable.
6. **Rotation-shader micro-opt** (tile the transposed writes through shared memory to
   restore coalescing, in patch 0005's `get_rotated_dst_coord` users): real but small —
   GPU is not the binding constraint and 0005-vs-0007 was fps-neutral. Backlog only.

## Avenue 5 — what debugfs can and cannot tell us

- Useful: `/sys/kernel/debug/dri/0/crtc-0/status` (live mixer config + a rolling
  "vblank fps" counter — read 95 during the session with a game up),
  `/sys/kernel/debug/dri/0/state` (which planes/fbs/formats are actually flying),
  `/sys/class/devfreq/3d00000.gpu/*` (GPU busy/freq), `gamescopectl` on the device for
  live convars (`vblank_debug 1` = per-vblank scheduling spew, `composite_debug` flags)
  — all with no install and no restart.
- Not available: upstream DPU has **no per-frame composite-cost / utilization counters**
  (`core_perf` is a downstream-SDE feature; our `perf` debugfs node is empty and `kms` is
  a one-shot register snapshot). Per-frame timing evidence must come from the gamescope
  side (`vblank_debug`, the proven strace-`msgrcv` instrument from the base-bump
  investigation) plus `/sys/kernel/debug/tracing` drm/msm events if needed.

---

## Ranked interventions (gain × risk × effort)

| # | Intervention | Expected native gain | Risk | Effort |
|---|--------------|----------------------|------|--------|
| 1 | Game VSync/present-mode audit + fix | up to +5–9 fps if FIFO-blocked (could be the whole prize) | ~zero (one game setting) | minutes |
| 2 | Instrument the 48 ms (vblank_debug, strace msgrcv, gpu trace) | 0 directly; decides #3/#4 | ~zero (read-only + convar) | 1 session |
| 3 | Gamescope pacing change (commit-triggered composite / scheduler tuning) | +3–8 fps (if #2 confirms chain latency) | medium, userspace-only — crash/rollback via pacman, NOT the DPU class | days |
| 4 | 60 Hz driver-mode A/B | unknown, plausibly ≤0 | modeset class — only with the watchdog procedure | hours |
| 5 | Rotation-shader write-coalescing micro-opt | +0–2 fps | low | days |
| 6 | DPU plane rotation (catalog hack) | — | — | REJECTED: HW/driver cannot rotate RGB or >1088px (Avenue 1) |
| 7 | Landscape panel / Vulkan pre-rotation | — | — | REJECTED for Proton titles (Avenue 3) |

## First experiment, next session

**STEP 0 ANSWERED 2026-08-16 (later session):** `VSync = Off` (parsed from
UserSettings.json over ssh; the flat grep below doesn't match — the file stores
name/value objects, value is `UI-Settings-Video-QualitySetting-Off`). CAVEAT: read
*after* an intervening settings-manipulation session (which reached 42.33 with FSR3
Performance + FG) — unknown whether VSync was off during native runs G/I, so before
concluding "VSync was never the blocker", re-bench native once with VSync verifiably
off. If native still ~21 → take the instrumentation branch below. Also noted: 42
presents/s under FG proves the chain can cycle at ~24 ms — the 48 ms floor is
game-frame-path latency, not a present-chain hard cap.

**Step 0 — read the game's present state (read-only):**
```
grep -o '"VSync":[a-z]*' "/home/deck/.local/share/Steam/steamapps/compatdata/1091500/pfx/drive_c/users/steamuser/AppData/Local/CD Projekt Red/Cyberpunk 2077/UserSettings.json"
```
Also check whether our MangoHUD build can show the swapchain present mode (a
`present_mode` config param exists in recent MangoHUD; verify on-device rather than
trusting this note).

**Step 1 — if VSync is on, turn it off and re-bench:**
- Game closed, either toggle VSync off in the game's video settings (verify the exact
  menu location on-device) or edit the `"VSync"` value in `UserSettings.json`.
- Everything else identical to bench run I (mesa 26.3.0-dev, `pocknix-power-mode max`,
  fan max, native — FSR/FG off, verified in the file pre-run per the bench doc's trap
  notes).
- Run the built-in benchmark; record fps + mid-run `cat /sys/class/devfreq/3d00000.gpu/cur_freq`.
- Watchdog during the run: `dmesg -w | grep -Ei "ppdone|vblank.*timeout"` (expect silence —
  this experiment touches no KMS state, but we log it anyway).

**Revert path:** restore the single `"VSync"` value in `UserSettings.json` (or re-toggle
in-game). Nothing else is touched — no packages, no kernel, no gamescope flags.

**Decision tree:**
- Native ≥ ~25 fps → FIFO block confirmed; ship the finding (and consider defaulting
  players to VSync-off under gamescope, where tearing cannot happen anyway) and proceed
  to #3 for the remainder.
- Unchanged (or VSync was already off) → run the instrumentation branch in the same
  session: `gamescopectl vblank_debug 1` (live, no restart), the strace-`msgrcv`
  instrument on the gamescope/mangoapp pair, and a parallel frametime capture, to split
  the 48 ms into game-GPU / wait-for-latch / composite / commit-to-release. That number
  decides between pacing work (#3) and the 60 Hz A/B (#4).

## INSTRUMENTATION RESULTS 2026-08-16 (live session) — PREMISE REVISED

Measured during benchmark runs J (native, 22.98/23.01) and K (FSR3 Performance, FG off,
31.91), VSync verifiably off, max power/fan, 26.3.0-dev, lsfg off (env-verified):

- **Game GPU busy ~91% at native, ~87% at quarter-res** (drm fdinfo `drm-engine-gpu`,
  summed over unique drm-client-ids of GameThread — NOT the old 52% number, source of
  which is unknown/other-era). Gamescope's composite: **~6% GPU**.
- Frame-time model that fits both runs: **frame = game GPU work + ~4 ms overhead**
  (native: 39.6+3.9=43.5 ms; quarter-res: 27.3+4.0=31.3 ms).
- gamescope `vblank_debug`: drawTime ~9–10 ms vs the 8.33 ms budget → **chronic
  "missed vblank" every cycle** (its 2–3 ms composite queues behind the saturated GPU).
  This is latency, not the fps ceiling.
- **CONCLUSION: the device is GPU-WORK-bound, not wait-bound.** The present-path tax is
  ~4 ms/frame. Pacing surgery (intervention #3) upside is bounded: ~+15% at 32 fps if the
  whole 4 ms vanished. Downgraded from "the prize" to "worthwhile polish, later."
- **The real levers are GPU-work levers:** internal-resolution scaling (K proved +39%),
  turnip A8xx maturation, and cheap frame-gen. NOTE: the game's own FSR3 FG costs ~16 ms
  per real frame on this GPU (42.33 presented ⇒ ~21 real base vs 31.9 without FG) —
  in-game FG is a terrible deal here; lsfg (~1.5 ms/gen frame) over an FSR3-Performance
  base is the config to validate (expected ~60 presented over a ~30 base).
- **VALIDATED same session:** FSR3 Performance + game-FG off + lsfg 2x measured in
  gameplay = **56.7 presented fps / ~28.4 real base** (crtc `total_framecount` delta —
  which also proves lsfg frames genuinely present; per-real-frame GPU 29.6 ms ≈ K's
  27.3 + ~2 ms lsfg). Shipped as the recommended AAA config (bench-plan doc).

## Most promising avenue, in short

Hardware rotation and pre-rotation are provably dead ends on this SoC; the rotation
shader itself is nearly free. The tax is that rotation forces a full composite every
frame, which welds the game's present to gamescope's vblank-anchored
latch→composite→commit→release chain. The cheapest, highest-yield attack is therefore on
the **wait**, not the **work**: first check whether the game is FIFO-blocked (VSync), then
instrument and shorten the chain in gamescope userspace — never via `-r`, generated
modes, or anything else in the DPU modeset class.
