# Hardware display rotation experiment — DPU inline rotation + gamescope 3.16.29 (2026-09-20)

**Status: PREPARED. Nothing built, nothing merged, nothing on the device.** Everything here
lives behind three opt-in switches so the default kernel, the default package set and the
default launcher line are byte-for-byte unchanged. Cliff decides whether/when to run it.

Trigger: Armada release 20260915 — "Improved game performance due to hardware display
rotation on SM8550/SM8650/SM8750" — on the same panel, same DPU. Sweep item K11
(`docs/upstream-sweep-2026-09-20.md`) and the Valve-side sweep
(`docs/upstream-sweep-2026-09-20-valve.md`, section 1) are the sources; this doc is the plan.

## 1. What changes, and why it should move fps

Today (shipped): gamescope Valve `4286887` + ROCKNIX 0005 `--use-rotation-shader`. Every
frame is fully composited, with the composite shaders writing their output transposed into
a physical-portrait 1080x1920 XR30 UBWC image, which the DPU scans out unrotated
(`rotation=1`). Direct scanout is impossible by construction
(`bNeedsFullComposite |= rotationShaderOrientation != 0`), so even a bare fullscreen game pays
a composite + the present chain behind it every frame. `docs/present-path-attack-plan.md`
measured the ceiling (~21 fps Cyberpunk native, GPU ~52 % busy) and, in its Avenue 1,
declared DPU rotation dead because the only rotation format list in the 7.1.3 tree was
`{NV12}` and the composite was "1920 wide pre-rotation (> 1088)". **Both premises are
superseded**, which is what makes this experiment worth running:

- ROCKNIX PR #3299 (tiopex, merged 2026-09-11) adds a rotation config for the SM8750 VIG
  SSPPs with an RGB format list (`rotation_v201_formats`: NV12/P010 + the 8888 family +
  ARGB/ABGR/XRGB/XBGR2101010) and `rot_maxheight = 1088`, plus generic fixes in
  `dpu_plane.c`/`dpu_rm.c` (CW/CCW XOR on rot90, check the pre-rotated **height**, keep QSEED
  programmed for 1:1 RGB when rotating, `test_bit` reservation). The catalog only ever
  advertised rotate-0/180 + reflect on this SoC because the feature bit was missing, not
  because the hardware lacks it (DPU 12.0 has the v2.0.1 inline rotator, same family as
  Kalama/SM8550).
- "Pre-rotated height" is the height of the **source buffer** the plane reads, i.e. the
  logical landscape composite or the game's own buffer: 1920x1080 -> 1080 lines, under the
  1088 cap. The old note counted the transposed image's width. (Panels wider than 1088 in
  portrait — 1440x2560 — do hit the cap; that is what ROCKNIX's gamescope 0008
  `--rotated-output-max-height` is for. The Odin 3 does not need it.)
- Valve gamescope gained native handling of both cases in `38fb50f` (merged 2026-08-13):
  when the primary plane advertises the needed 90/270 bit it scans out **rotated**
  (`DRMBackend.cpp` 3.16.29: `drm_set_mode()` :3411-3435 sets `g_bRotated` and leaves
  `g_uOutputRotation = 0`; the liftoff layer gets `rotation = ROTATE_90/270` at :2710 and the
  CRTC rects are transposed at :1945-1955), and when the plane cannot, it rotates in the
  composite pass itself (`g_uOutputRotation = uStep` :3435, `bNeedsFullComposite |=
  g_uOutputRotation != 0` :3699 — same class as our 0005, so **38fb50f alone is still full
  composition and moves nothing**; the fps lever is the kernel half).

With both halves in place the expected picture is: a fullscreen game buffer (or the Steam UI
composite) on one VIG plane, `rotation=ROTATE_90`, no composite pass for a bare game, and the
present chain shortened by one vblank-anchored hop. That is exactly the "no direct scanout
because of rotation" tax the attack plan identified as the prize. It is also the fix for the
Vulkaiser class (HANDOFF 2026-09-03 finding #3: a game that picks the raw 1080x1920 mode goes
direct-scanout and shows up sideways because only the composite path rotated) — the DPU now
rotates whatever is scanned out.

## 2. The pieces (all on branch `worktree-agent-aaa02742fb15ad1b4`, unbuilt)

### 2a. Kernel — `kernel/sm8750/patches/50-rotation-exp/` (OPTIONAL series)

| file | origin | dry-run on pristine 7.1.3 + full 10/20/30/40 stack |
|---|---|---|
| `0013-drm-msm-dpu-fix-inline-rotation.patch` | ROCKNIX `packages/linux/patches/7.2/0013`, 180057b (PR #3340, 2026-09-17), split out of ec3d53baac (PR #3299) | **fuzz 0, no offset** |
| `0068-drm-msm-dpu-enable-sm8750-inline-rotation.patch` | ROCKNIX `devices/SM8750/patches/linux/0068`, ec3d53baac (PR #3299, 2026-09-11) as reduced by 180057b | **fuzz 0, no offset** |

Verification: `scratchpad/kverify-rot2/apply-series.sh` reproduces `build-kernel.sh`'s
`apply_patches()` (patch(1), `-f`, default fuzz, numeric dir order) on a fresh extract of the
pinned tarball (sha256 `be41c068…` = `kernel.conf`). Result: 10-mainline 5, 20-sm8750 46,
30-version 2, 40-holodor 20, 50-rotation-exp 2 — all applied; the two new patches at fuzz 0
with no offsets; the pre-existing fuzz set (0002, 0006, 0028, 0039, 0501, 0504-compat-input,
0601, 0701, 1300) is the same status quo the 09-20 sweep verification recorded. The patched
tree resolves every symbol the hunks reference (`_VIG_SBLK_ROT`, `DPU_SSPP_INLINE_ROTATION`,
`inline_rotation` in `_dpu_plane_setup_scaler3()`), i.e. 7.1.3 already carries the SC7280
inline-rotation plumbing the patches hook into. Not compiled.

Armada equivalents: 1670abf (2026-09-11) `packages/kernel/patches/0066-drm-msm-dpu-enable-
inline-rotation.patch` is ROCKNIX's 0068 + 0013 merged into one patch for SM8550/SM8650/SM8750
(one shared `VIG_ROT_V201_MASK_SDMA` / `dpu_rot_v201_cfg`, one `_rot_v2` sblk per QSEED
revision); the SM8750 hunks are content-identical to ours apart from those two names. Armada
also took 0067 (QSEED detail enhancer) in 1670abf and **dropped it the next day** (bdaac16,
09-12: hardcoded sharpening curves, untuned; writes `DE_LPF_BLEND` which QSEED 3.0 on SM8250
lacks). We do not carry 0067.

Gate: `scripts/build-kernel.sh` now skips any `patches/<series>/` dir that carries a file named
`OPTIONAL` unless `HOLODOR_KERNEL_EXTRA_SERIES` lists it (a listed-but-missing name is a hard
error). When a series is selected, `CONFIG_LOCALVERSION` is stamped with it, so the
experimental kernel reports `uname -r` = `7.1.3-50-rotation-exp` and its modules live in their
own `/usr/lib/modules/7.1.3-50-rotation-exp/`. Unit-tested: without the variable
10/20/30/40 apply and 50 is skipped; with it, 50 applies.

### 2b. Gamescope — `packages/gamescope-next/` (OPTIONAL package)

Pin: Valve **3.16.29 = `8f212644c46460549035971ab914421180f61a7c`** (2026-09-14), not ROCKNIX's
3.16.28/fa0b4d3, per the Valve sweep: same 0001/0004 applicability, plus the Adreno work
(a88f8ff RCAS one pixel/thread on Qualcomm, 8543837 Valve's own Snapdragon GSR1 as filter 5,
2f27e92 composite gating), `2d217a1` (09-13) fixing the plane-format validation regression
`f8be7ee` (07-07) introduced — f8be7ee *is* in fa0b4d3 — and the 09-14 nested-menu/focus
batch in our QAM/menu-freeze family (cead6ff, 5b7bb4a, d964b0d, a258253, 5a33808, 8f21264).

Patch decisions (dry-run on a `git archive` of 8f21264, `scratchpad/kverify-rot2/gs-test2.sh`):

| patch | decision | result on 3.16.29 |
|---|---|---|
| 0001 wl_touch | keep (byte-identical to ROCKNIX's at fa0b4d3; nested Wayland backend only, parity) | fuzz 0, offsets 11/43/63 |
| 0004 GAMESCOPE_FAKE_OUTPUT_MM | keep (byte-identical to ROCKNIX's; the launcher depends on it for the 275-dpi UI) | fuzz 0, offset 34 |
| 0005 rotation shader | **DROP** — upstream 38fb50f is the same idea natively; 30 hunks fail on this base | n/a |
| 0006 XTest cursor | keep, **REBASED**: d12ec39 (08-17) rewrote `MouseCursor::UpdatePosition`, the original fails at :1566. Regenerated against the new body; keeps d12ec39's `m_bConstrained` meaning (active constraint only) while taking the position from `XQueryPointer` as ROCKNIX does | fuzz 0, no offset (original: 1/1 hunk FAILED) |
| ROCKNIX 0005 steam-focus-fallback | not taken (sweep U4, Steam-update black screen; not a rotation variable) | applies F0 if wanted |
| ROCKNIX 0007 SGSR1 | **never stack** on 3.16.29 — Valve's 8543837 GSR1 is already there as filter value 5 | applies F0, but collides in design |
| ROCKNIX 0008 `--rotated-output-max-height` | not taken: Odin 3 is 1080 lines pre-rotation, under the 1088 cap. Keep in reserve (see failure signatures) | applies F0 |

Package identity: `pkgname=gamescope-next`, `epoch=1`, `pkgver=3.16.29.valve.8f21264`,
`provides=(gamescope=1:3.16.29.valve.8f21264)`, `conflicts=(gamescope)`, no `replaces` — the
mesa-next pattern: installed on purpose with `pacman -U`, never pulled by `-Syu`. Deps, meson
options, tuning flags and the CAP_SYS_NICE scriptlet are copied from `packages/gamescope` so
the only variables are the base commit and the rotation path. The dir carries an `OPTIONAL`
marker and `scripts/build-packages.sh` now skips such dirs unless named
(`make packages PKG=gamescope-next`), so a plain `make build` cannot leak it into localrepo —
the way the staged mesa-next-6 trio leaked into an RC on 2026-09-06.

Not yet checked (needs the chroot): the newer submodules (wlroots 0.20 `fc6a965`,
libdisplay-info 0.4.0 `1c71cb5`, meson >= 0.60 `a63f16b`) build under our `-Wno-error` and
ALARM's library versions.

### 2c. Launcher — `packages/pocknix-steam/pocknix-steam`, pkgrel 41 -> 42

New switch `POCKNIX_ROTATION` (environment, or set in `/etc/pocknix/device.conf`, which the
launcher sources): `shader` (default; the launch line is unchanged) or `hw` (drops
`--use-rotation-shader`; everything else identical). `hw` is only valid with gamescope-next —
the shipped gamescope would still accept it, but gamescope-next aborts on the unknown
`--use-rotation-shader` option, which is why the switch exists at all.

**-W/-H answer: native portrait, unchanged.** In 3.16.29 `-W`/`-H` set
`g_nPreferredOutputWidth/Height` (`main.cpp:748-752`), which reach `init_drm()`
(`DRMBackend.cpp:1256`, `drm->preferred_width/height`) and are used *only* to pick the
connector mode: `setup_best_connector()` :1145 calls `find_mode()` :978, which matches
`hdisplay`/`vdisplay` against the connector's mode list. The Odin 3's DSI panel only lists
1080x1920 modes, so `-W 1080 -H 1920` is the value that matches (a landscape 1920x1080 would
miss and fall through to a generated/CVT timing — the `-r 120` DPU-wedge family, HANDOFF
"Hard-won knowledge" 2). `drm_set_mode()` :3411-3425 then derives the LOGICAL size itself for
the 90/270 orientations (`g_nOutputWidth = mode->vdisplay` = 1920, `g_nOutputHeight =
mode->hdisplay` = 1080, `g_bRotated = true`). The shader build behaved the same way for -W/-H
(0005 only changed where the transposition happened), so `device.conf` needs no change.
`--force-orientation` keeps its token too (`right` on the Odin 3, Armada-verified): the same
`GamescopePanelOrientation` enum feeds the plane `rotation` property (:2693-2710) and the touch
mapping (`wlserver.cpp:3200`), so picture and touch rotate together in either mode. If the
first hw boot comes up upside-down, that is the CW/CCW convention of the DPU rotator vs DRM
(what 0013's XOR is meant to settle) — flip the token to `left` as the diagnostic, and report
it upstream rather than shipping the flip.

## 3. Touch — what changes when the rotation moves from the shader to the DPU

Nothing in the mapping, by construction:

- The DRM session's touch never goes through our 0001 patch (that wires `wl_touch` for the
  **nested Wayland backend**, i.e. gamescope running inside KDE; on the device the DRM backend
  gets touch from wlroots/libinput). It is kept only for parity with ROCKNIX.
- wlroots delivers normalized 0..1 coordinates in the touchscreen's own frame (the FT5426
  reports 0..1080 x 0..1920 per the DT `touchscreen-size-x/y`, i.e. physical portrait).
  `wlserver_touchmotion()` / `touchdown()` apply `apply_touchscreen_orientation(connector->
  GetCurrentOrientation(), …)` (`wlserver.cpp:3200-3232`, called at :3242 / :3302) and then
  scale by the LOGICAL `g_nOutputWidth/Height`. That function is byte-identical between our pin
  4286887 and 3.16.29 (diffed), and 0005 never touched `wlserver.cpp` (its file list is
  DRMBackend/main/rendervulkan/shaders only). The inputs to it — the orientation enum and the
  logical size — are the same in shader and hw mode. So a touch at a given physical spot maps
  to the same logical pixel whichever engine rotates the pixels.
- 3.16.29 does carry `5177f02` (touch scaling now follows the **mouse-focus** connector
  instead of the global focus) and `47ee8da` (release touch buttons when the focus surface
  goes away). Neither changes single-display behaviour; both are worth one tap test each in
  the protocol because they are new since our pin.
- **libinput calibration matrix:** we ship **no** `ENV{LIBINPUT_CALIBRATION_MATRIX}` rule
  anywhere (`grep -r` over `devices/`, `packages/`, `HANDOFF.md`, `docs/` is empty), and none
  is needed: gamescope does its own orientation mapping from the connector, and kwin in
  Desktop Mode maps touch through the same DRM `panel orientation` property it uses for the
  picture. A calibration matrix would only enter the picture if the touch controller's frame
  differed from the panel's (it does not — both are the native portrait), and it would be
  wrong to add one *for* the DPU rotation: the DPU rotates pixels on the way out, it does not
  change which physical spot a logical pixel lands on. If touch is ever off in hw mode, the
  suspect is the orientation token (see 2c), not a matrix.
- Cursor: 0006 (rebased) keeps the XTest-moved gamepad cursor repainting. With direct scanout
  active, upstream forces a composite while a cursor is visible unless the `drm_cursor_plane`
  convar is on (`DRMBackend.cpp:64`, default off; `bNeedsFullComposite |= !cv_drm_cursor_plane
  && bDrewCursor` :3677). Leave it off until scanout is proven, then try
  `gamescopectl drm_cursor_plane 1` as a separate step — the msm cursor plane is untested
  here.

## 4. Building the experiment (host: fusor, this worktree checked out)

```
# kernel with the optional series (release string becomes 7.1.3-50-rotation-exp)
HOLODOR_KERNEL_EXTRA_SERIES="50-rotation-exp" make kernel DEVICE=odin3
# package it: bump packages/linux-pocknix-sm8750/PKGBUILD pkgrel (27, note "EXPERIMENT:
# 50-rotation-exp") on this branch first so `pacman -Q` tells the two kernels apart, then
sudo make packages PKG="linux-pocknix-sm8750 pocknix-steam"
# gamescope-next (opt-in; ~20 min; a plain `make packages` never builds it)
sudo make packages PKG=gamescope-next
```

Outputs land in `build/localrepo/`: `linux-pocknix-sm8750-7.1.3-27-aarch64.pkg.tar.*`,
`pocknix-steam-0.1.0-42-any.pkg.tar.*`, `gamescope-next-1:3.16.29.valve.8f21264-1-aarch64.pkg.tar.*`.
Do not `make build` / respin an RC from this branch: the RC must stay on the shipped kernel-26
+ gamescope-3 until the A/B is decided (`feedback-rc-repo-build-parity`: nothing lands in the
repo's default set from here).

Before touching the device: `pacman -Q linux-pocknix-sm8750 gamescope pocknix-steam` and copy
the three shipped `.pkg` files out of `/var/cache/pacman/pkg/` (or `build/localrepo/`) to
`~/rollback-rotation/` on the device. Those are the rollback.

## 5. Deploy

**In place over ssh (the way kernel-25/26 went in, HANDOFF 09-06):**

```
# odin3 = the ssh alias for the Odin 3 (192.168.1.32 on wifi; the USB-C hub ethernet gets a DHCP lease)
scp build/localrepo/{linux-pocknix-sm8750-7.1.3-27,gamescope-next-1:3.16.29.valve.8f21264-1,pocknix-steam-0.1.0-42}*.pkg.tar.* odin3:/tmp/
ssh odin3 'systemd-run --unit=holodor-rot-inhibit --collect systemd-inhibit --what=sleep:idle --mode=block sleep 8h'
ssh odin3 'sudo pacman -U /tmp/linux-pocknix-sm8750-*.pkg.tar.* /tmp/gamescope-next-*.pkg.tar.* /tmp/pocknix-steam-*.pkg.tar.*'
#  -> the 90-linux-pocknix hook rebuilds /flash/KERNEL (check its md5 sidecar + KERNEL.bak = kernel-26)
#  -> pacman asks to replace gamescope with gamescope-next: yes
ssh odin3 'printf "POCKNIX_ROTATION=hw\n" | sudo tee -a /etc/pocknix/device.conf'
ssh odin3 'sudo reboot'
```

Hold the inhibitor for the whole session (`feedback-device-sleeps-hold-inhibitor`). The three
installs can be split for bisection: kernel alone (planes advertise rotate-90, shipped
gamescope pins `rotation=ROTATE_0` while the shader is on -> no visible change, a
sanity/regression step), then gamescope-next + launcher (`POCKNIX_ROTATION=hw`).

**Test card instead:** flash the current RC to a spare SD, boot it, run the same three
`pacman -U` + device.conf line there. Internal install untouched; rollback = pull the card.

**First-boot checks (gamescope log `~/pocknix-steam.log`, `dmesg`):**
- `modetest -M msm -p | grep -A1 rotation` on the new kernel must list `rotate-90`/`rotate-270`
  on the VIG planes (sspp_0..3); the shipped kernel shows only 0/180 + reflect.
- gamescope log: `selecting mode 1080x1920@…`, no "Rotate in the compositor" fallback; then
  `/sys/kernel/debug/dri/0/state` should show the game/UI plane with `rotation=` 2 or 8
  (ROTATE_90 / ROTATE_270 bits) and, for a bare fullscreen game, **no** composite FB.
- `dmesg -w | grep -Ei "ppdone|vblank.*time.*out|timeout|inline rot|dpu"` for the whole first
  session. Any command-mode timeout = stop, roll back, keep the log.

## 6. A/B protocol (tools/ab, `docs/cyberpunk-bench-plan.md` rules)

One variable at a time. The rotation stack is three packages, but the *variable* is "where the
rotation happens"; keep the mesa pin, FEX rootfs, power/fan modes and game settings identical to
the 09-06 baseline (A = mesa-next-5 trio, 1280x720 native, VSync off, QuickPresets Low, bench
mode, fan performance, 130 s warm-up).

| side | stack | switch |
|---|---|---|
| A | kernel-26 + gamescope-3 (shader) | shipped; `POCKNIX_ROTATION` unset |
| B | kernel-27(rot) + gamescope-next + `POCKNIX_ROTATION=hw` | DPU scanout rotation |
| B' | same as B, plus `--force-composition-rotation` added to the launch line (or `gamescopectl` if exposed) | composited rotation on the NEW gamescope, same kernel — isolates "gamescope bump" from "DPU rotation" without a reboot |
| A' | A again, fresh boot | reboot control, as on 09-06 |

Measure per side (3 runs each, `abrun.sh`, `absample.sh` at 1 Hz): benchmark avg fps (results
screen), **presented fps** (`crtc total_framecount`, the meter that told the lsfg story), GPU
MHz + busy, W, temps. Baseline to beat: **22.11 / 22.06 avg fps** (A / A', 09-06), run-to-run
spread ±0.06. The attack plan's arithmetic says the present-path tax is worth up to ~30 fps at
the same GPU load; anything under +1 fps is noise and "no direct scanout actually happened" —
check `dri/0/state` before believing a null.

Functional checks (each side, before the bench):
1. Steam UI orientation: Big Picture upright, correct handedness (left/right not mirrored),
   text crisp (a 1:1 plane with QSEED programmed — 0013 keeps the scaler on for rotated RGB —
   should look identical to the shader; a softening means the scaler is resampling).
2. Touch mapping: tap the four corners of the Steam UI + a drag in the library; tap inside a
   game (Balatro). With 5177f02 also tap while the QAM is open over a game.
3. QAM / overlay: open the Quick Access Menu and the Steam overlay over a running game. Under
   hardware scanout the game and the overlay are separate planes for the first time; Armada
   needed a libliftoff fix (their gamescope 0021 "preserve stacking across multiple primary
   planes", virtudude: the msm DPU exposes several primary planes and liftoff could put the
   overlay *below* an opaque game) — if the QAM is invisible or flickers behind the game,
   that is the symptom; the fallback is `--force-composition-rotation` for the session and a
   port of Armada's 0021 (armada-packages `gamescope/patches/0021`) as the next step.
4. A sideways-prone game: Vulkaiser (appid 349680) — the HANDOFF #3 case. Expected: upright
   now (whatever it scans out gets rotated by the DPU). Also one 1080x1920-native emulator
   window if handy.
5. Suspend/resume: one lid-style `systemctl suspend` from the Steam UI and one from inside a
   game; on resume check the picture is still rotated (the plane's rotation property survives
   the DPU power cycle? — the driver reprograms it from the atomic state, but this is the first
   time the rotator is in that state), touch still maps, `dmesg` clean.
6. Desktop Mode: switch sessions. kwin reads the same `rotation` plane property and, now that
   it advertises 90/270, may move from compositing the rotation to a rotated scanout by itself
   — no config change on our side (`pocknix-desktop` sets no rotation, only the scale). Check:
   upright, touch, kdialog/panel placement, and switch back. If kwin misbehaves the kernel is
   the variable (it does not know about gamescope), so this is also the "is the DPU rotation
   itself sound" test independent of gamescope.
7. mangoapp overlay on/off — the frame-pacing area (`wlserver_app_presented`, per-connector
   mangoapp rework `89fb3f0`…) moved in 3.16.29; re-check ring-0 composites vs presents
   (PKGBUILD header of packages/gamescope explains the trap).

## 7. Rollback

```
ssh odin3 'sudo pacman -U ~/rollback-rotation/linux-pocknix-sm8750-7.1.3-26-*.pkg.tar.* ~/rollback-rotation/gamescope-1:3.16.0.rocknix.4286887-3-*.pkg.tar.* ~/rollback-rotation/pocknix-steam-0.1.0-41-*.pkg.tar.*'
ssh odin3 'sudo sed -i "/^POCKNIX_ROTATION=/d" /etc/pocknix/device.conf; sudo reboot'
```

pacman replaces gamescope-next with gamescope (conflicts), the 90-hook rebuilds `/flash/KERNEL`
from kernel-26, `/usr/lib/modules/7.1.3-50-rotation-exp` goes away with the package. If the
device does not boot the experimental kernel at all: `/flash/KERNEL.bak` is kernel-26's image
(the hook keeps it), so the ABL path from the 09-11 notes applies — but a DPU catalog change
cannot stop the boot before the panel; the realistic bad case is a black or wedged panel with
ssh alive, which the pacman line above fixes. Partial rollback is allowed: the launcher switch
alone (`POCKNIX_ROTATION` unset with gamescope-next installed) gives composited rotation on
the new gamescope; gamescope-next alone on kernel-26 is the same; the kernel alone with the
shipped gamescope is invisible.

## 8. Risks and failure signatures

- **Never reintroduce `-r`.** The refresh-switch path generates modes and modesets the
  command-mode DSI pipeline (HANDOFF "Hard-won knowledge" 2: ppdone/vblank timeouts x118 per
  boot). Nothing here changes -W/-H or adds -r; `--rotated-output-max-height` (not used) would
  add one more `find_mode()` by panel size — fine — but `drm_set_refresh()` stays untouched.
  Watch `dmesg` for `ppdone`/`vblank … timed out`/`ctl start interrupt wait failed` in every
  session; one hit = stop.
- **UBWC / format constraints from the patch.** `dpu_plane_check_inline_rotation()` requires
  `MSM_FORMAT_IS_UBWC(fmt)` AND the format in `rotation_v201_formats`. gamescope's composite is
  XR30 UBWC (`modifier 0x500000000000001`), which qualifies. A **game buffer** scanned out
  directly must also be UBWC and one of those formats; a linear or RGB565/NV12-non-UBWC buffer
  makes the atomic test fail and gamescope silently composites (liftoff falls back) — that is
  correct behaviour, but it means "direct scanout" depends on what turnip/FEX hand over.
  Confirm with `dri/0/state` per game; a game that never gets direct scanout is a
  driver-format question, not a rotation bug.
- **Black panel, every atomic commit rejected** (the ROCKNIX 0008 signature): the plane says
  `rotate-90` unconditionally but the rotator refuses a source taller than 1088 lines. Odin 3
  sources are 1080 lines; a game window or overlay laid out taller than 1080 in the pre-rotated
  frame (should not happen — the logical output is 1920x1080) would trigger it. Signature in
  the gamescope log: repeated `drmModeAtomicCommit` / `Failed to prepare … flip` errors with no
  frames presented. Remedy: add ROCKNIX 0008 to gamescope-next and launch with
  `--rotated-output-max-height 1080`, or `--force-composition-rotation`.
- **"Primary plane doesn't support any formats >= 8888"** at init (`DRMBackend.cpp:1401`):
  the f8be7ee format validation (in 3.16.28 and 3.16.29) rejects every plane format unless the
  Vulkan device supports it with modifiers; 2d217a1 (in 3.16.29, not in fa0b4d3) is the fix
  for devices without `VK_EXT_image_drm_format_modifier`. Turnip exposes modifiers so it should
  not fire; if it does, that is the line, and the culprit is the mesa side, not rotation.
- **kwin behaviour change** in Desktop Mode (see check 6): the kernel change is global; kwin
  will see rotate-90/270 and may take the plane path. If Desktop Mode regresses while the Steam
  session is fine, the experiment can still ship for gaming by making kwin prefer software
  rotation (kwin has no switch for that today — it would mean the kernel series is not
  shippable until kwin behaves), so treat a kwin regression as a blocker, not a footnote.
- **Overlay stacking** (check 3) — Armada's 0021 story; possible, known, has a fallback.
- **Cursor plane**: leave `drm_cursor_plane` off; the msm cursor plane path is untested and
  every visible cursor forces a composite with it off, which is the shipped behaviour anyway.
- **Suspend/resume** with a rotated scanout plane is new territory for this DPU driver on this
  kernel (the plane state is replayed by atomic resume; the rotator block's own reset is
  inside DPU's power domain). One plugged and one unplugged sleep before any long soak.
- **Two changes in one package bump**: gamescope-next is 4286887 -> 8f21264 (201 commits from
  our pin, 122 past fa0b4d3) *and* the rotation path. Side B' (composition rotation forced on
  the new gamescope) is the control that separates them; do not skip it.
- **QSEED detail enhancer (0067)** is deliberately absent; if the picture looks softer than the
  shader's, that is the scaler at 1:1 (0013 keeps it on for rotation) and not a reason to add
  0067 — Armada dropped it as untuned.

## 9. If it wins

Promote: move the two kernel patches into `20-sm8750/` (numbers per the series README),
delete `50-rotation-exp/`, drop the `HOLODOR_KERNEL_EXTRA_SERIES` gate use (the mechanism can
stay), rename gamescope-next -> gamescope (bump epoch/pkgver so the upgrade path is clean,
carry the rebased 0006, delete 0005), make `POCKNIX_ROTATION=hw` the default in the launcher
(or drop the switch), update `PATCHES.md` (gamescope + kernel rows) and the pocknix-steam
launcher comments, then K12 (Armada LUTDMA colour management) becomes the next Phase 7 item —
it only matters with direct scanout, which is what this experiment buys.

## Verification artifacts (scratchpad, not committed)

`/tmp/claude-1000/-home-cliff-projects-holodor/259587d6-8976-473b-a23e-bf3229b67791/scratchpad/kverify-rot2/`:
`apply-series.sh` + `full.log` (kernel), `gate-test.sh` (build-kernel.sh gate), `gs-test2.sh`
(gamescope-next patches on 8f21264), `gen-0006.py` (the 0006 rebase generator),
`gamescope-8f21264/` (git-archive export of the pin).
