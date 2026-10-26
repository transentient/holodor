# Upstream sweep, 2026-09-20, part 2: Valve, Collabora, Mesa, FEX, Proton

Companion to docs/upstream-sweep-2026-09-20.md (ROCKNIX / ArmadaOS). Produced by a research agent
(Claude Fable 5.1) at Cliff's request ("did you check the Valve / Collabora stuff too?"). Read-only.

# Upstream sweep 2026-09-20 — Valve / Collabora / Mesa / FEX / Proton side

Read-only; nothing in the repo changed. Clones/scratch in `/tmp/claude-1000/-home-cliff-projects-holodor/259587d6-8976-473b-a23e-bf3229b67791/scratchpad/sweep2/` (`gamescope`, `mesa`, `fex`, `gamescope-since-4286887.txt`, `mesa-fd-since-pin.txt`). Read `docs/upstream-sweep-2026-09-20.md` first; nothing below repeats it.

## Pins (verified by reading the files)

- `packages/gamescope/PKGBUILD`: `_commit=428688779e48…` (Valve master 2026-06-12), pkgrel 3, patches 0001/0004/0005/0006.
- `packages/mesa-next/PKGBUILD`: `_commit=bab34da4a378379e65d212b405525f50255efd31`, pkgver `26.3.0_devel`, pkgrel 5, no patches. **Confirmed in mesa main**: committed 2026-08-09 00:54 +0200, title "ci/broadcom: Update ci expectations after piglit uprev" (a CI commit — i.e. an arbitrary snapshot, not a driver landmark). `packages/mesa/PKGBUILD`: 26.1.5 tarball, pkgrel 3, no patches.
- `packages/fex-emu/PKGBUILD`: FEX-2607 `1cc4b93e`, patches 0001/0002/0005/0006. `packages/fex-rootfs/PKGBUILD`: ArchLinux rootfs `2026-01-08` + x86_64 `vulkan-freedreno 26.1.5-1` overlay.
- `packages/proton-cachyos/PKGBUILD`: `_srctag=11.0-20260702`, slr, arm64.
- `config/pocknix.conf`: `HOLO_MIRROR=…/holo-core-aarch64-preview/mash-20251118.3`.
- `PATCHES.md` housekeeping: the mesa row still says "25.1.5 tarball, 0001 c11/c23 shim" — stale vs both mesa PKGBUILDs.

## 1. Valve gamescope

**Window:** 4286887 → fa0b4d3 = 79 commits; fa0b4d3 → master `c50ddfa` (2026-09-17) = 122 more; 201 total. Tags: 3.16.25 `17baf4a` 07-21, 3.16.26 `565397f` 08-26, 3.16.27 `aa5b056` 08-27, **3.16.28 = fa0b4d3** 08-27 (ROCKNIX pin), **3.16.29 = `8f21264` 09-15**. Only two commits after 3.16.29 (pipewire build fix `4004d0b`, nested-Wayland attach fix `c50ddfa`).

**Our patches vs upstream** (`git apply --check`):
| patch | fa0b4d3 | 3.16.29 | master | upstream equivalent? |
|---|---|---|---|---|
| 0001 wl_touch | ok | ok | ok | no — still ROCKNIX-carried |
| 0004 FAKE_OUTPUT_MM | ok | ok | ok | no (`git grep OUTPUT_MM` empty) |
| 0005 rotation shader | **fails** (DRMBackend.cpp:1886, main.hpp:22) | fails | fails | **yes, in another form**: `38fb50f` "Add composited output rotation for displays that can't rotate at scanout" (authored 06-21, merged 08-13; in fa0b4d3). Auto-engages when the primary plane's rotation property lacks the 90/270 bit; `--force-composition-rotation` forces it on hardware that advertises but fails. Note its own commit text: while rotating this way "every frame is fully composited (no direct scanout, partial composition or cursor plane)" — same class as our 0005, so on its own it will not move the ~21 fps present-path ceiling; DPU inline rotation (K11) remains the lever. |
| 0006 XTest cursor | ok | **fails** (steamcompmgr.cpp:1566) | fails | no; broken by `d12ec39` (08-17, in 3.16.29) which rewrote `MouseCursor::UpdatePosition` — needs a small rebase |

**ROCKNIX's set on fa0b4d3** (`rocknix-next …/apps/gamescope/patches`): 0001, 0004, 0005-steamcontrolled-focus-fallback (new), 0006, **0007 SGSR1** (tiopex `61450dcec3` 09-10, own 450-line implementation adding `useGSRLayer0`), **0008 `--rotated-output-max-height`** (Philippe Simons `a42627166d` 09-12): the DPU inline rotator caps the pre-rotation source at 1088 lines but the plane advertises ROTATE_90 as a static capability; on 1440x2560 panels gamescope keeps scanout rotation, every atomic commit is rejected, black panel. `start_steam.sh` gates it: `TRANSFORM 90|270 && W -gt 1088 → --rotated-output-max-height 1080`. **Odin 3 (1080x1920, W=1080) is under the cap so the clamp is not needed** — but "plane advertises ROTATE_90, commits rejected, panel black" is the exact failure signature to watch for in the rotation experiment.

**msm/Adreno-specific (all in 3.16.29, none in fa0b4d3; author Matthew Schwartz, measured on Steam Frame's Adreno 750):** `a88f8ff` 09-11 RCAS one pixel/thread on Qualcomm (291→276 µs); `8543837` 09-10 Snapdragon GSR1 upscaler as filter value 5 (26% under FSR; SDR only) — collides in design with ROCKNIX 0007, so a bump to 3.16.29 should drop ROCKNIX's 0007 rather than stack; `2f27e92` gate composition on the base layer's filter; `2d217a1` 09-13 fixes a **regression introduced by `f8be7ee`** (07-07, *in fa0b4d3*): plane formats are now validated against the Vulkan device (sampled/storage/transfer), and devices without `VK_EXT_image_drm_format_modifier` failed init with "Primary plane doesn't support any formats >= 8888". Turnip exposes modifiers so fa0b4d3 is probably fine, but that log line is the tell.

**DRM backend:** `dd67fe5` 08-10 cursor plane behind `drm_cursor_plane` convar (default off; only matters once direct scanout works after K11); `b3a2f30` 07-28 unlink leftover foreign planes before modeset (fixes "requesting event but off" abort when a previous compositor left planes attached — relevant to our session switching); `25f929e` 04-10 (Collabora) carry the pending mode into the composite path when direct scanout fails — previously **mode/refresh changes were silently dropped while always compositing**, which is our current rotation-shader state; `f95dbda` clear inherited CRTC colour on enable; `3521d6b` VRR uncapped (no VRR panel, skip).

**Focus/menus (QAM/menu-freeze territory, 3.16.29):** `cead6ff` keep nested menus visible and correctly stacked, `8f21264` eight composite layers ("a fourth nested Dolphin menu on Frame trims the top-level menu"), `a990a0d`, `5b7bb4a`/`d964b0d`/`a258253`/`5a33808` (09-14 focus reroll fixes), `5140384`. Valve is doing Frame menu QA in exactly our freeze family; a bump gives that family a free re-test.

**Frame pacing/mangoapp:** `905a89b` only pace FIFO commits for windows the limiter covers, `00582ea`/`9e0642a` limiter protocol, per-connector mangoapp rework (`89fb3f0`, `4f96247`, `a039da9`, `dc5cf79`) — touches the `wlserver_app_presented`/mangoapp area the PKGBUILD header warns about; re-measure ring-0 composites vs presents after any bump.

**Touch:** `47ee8da` release touch buttons when focus surface is gone, `5177f02`, `2e9ea38`. **HDR/colour:** `6513879` content-driven HDR mode, `2dbc84d` EDID luminance fallback, Legion Go 2 PQ-backlight HACKs — AMD/OLED, nothing msm. **Build:** wlroots 0.19→0.20 (`fc6a965` 08-17), libdisplay-info 0.4.0 (`1c71cb5`), meson ≥0.60 (`a63f16b`) — all submodules, our `git submodule update --init` covers it.

**Recommendation:** for the rotation experiment pin **3.16.29 (`8f21264`)**, not fa0b4d3: same 0001/0004 applicability, plus the Adreno work and the `2d217a1` fix; cost is a rebase of 0006 over `d12ec39`. Drop 0005; launch with `--force-orientation left` and let 38fb50f/K11 decide; keep `--force-composition-rotation` as the A/B fallback.

## 2. Mesa main / turnip

162 freedreno commits since bab34da4 (to `e1f3f37` 09-19). Release state: 26.2.1 08-20, **26.2.2 09-02** (ROCKNIX), **26.2.3 09-16** (Armada), 26.1 ended at 26.1.8 (08-19); **no 26.3 branch/rc yet** (no `staging/26.3`, no tags).

**a8xx/gen8 items since our pin:**
- `7ea5e51c8a3` 08-31 Rob Clark "tu: Fix gen8 TEX_LINE_OFFSET" (should be in bits; Fixes eee7a6fb3581 gen8 descriptors) — **backported as `f9a4bfdadbc` into 26.2.2 and 26.2.3; our pin lacks it.**
- `d286f87b164` 08-24 Rob Clark "freedreno/fdl: Fix gen8 multi-plane descriptor base" (first plane addr must be the UBWC address; both single- and multi-plane gen8 descriptors used the Y-plane pixel address) — **not in 26.2.x**, not in our pin.
- `118ec7f45b1` 08-24 Connor Abbott "tu: Workaround 32B rollover bug in GPU firmware" (IB straddling a 4 GB boundary + preemption resumes from the wrong address; "affects all known firmwares/GPUs") — rare-hang class; not in 26.2.x.
- `189ee82449f` 09-07 ir3 quirk: prefetch `sam.s2en` reads src2 from fiber 0 → **GPU faults** when helpers disabled ("Fixes GPU faults in Devil May Cry 5"); not in 26.2.x.
- `90f3de6141b` drop `!filter_width` assert for 8xx (debug builds only).
- **UCHE / hangs: no commit since the pin mentions UCHE or a6xx+ hangs** (only a530 CI). Nothing new.

**Sparse / queue sync:** `73cd30791b1` 09-14 fix sparse bind column merging (Fixes 918e25e158c sparse residency) — in **26.2.3 only** (`bc9a84374bf`); `a071cafd9b0` don't advertise sparse residency when the pdev can't; D32S8 sparse props. Armada's `0001-disable-turnip-sparse-sync` (removes the gfx↔sparse timeline cross-wait from `0cc0e786e0` "tu/drm: Emulate combined gfx/sparse queues", 2025-10-08) **dry-run applies to our pin at offset -8**; the code it patches is unchanged in main → upstream has not touched that sync, so U2 remains the only mesa-side lever for the freeze family.

**Perf / extensions:** `99200197cc3`/`cc1cf17c2e0`/`10b1ef466fa` 09-04 SUBPASS(_SLICE)_FENCE for GMEM invalidation (fewer CACHE_INVALIDATEs for input attachments), `831f2cd8f41`, `688dbfc974e` vectorize scratch, `ea6b2f807d8` barrier-workgroup register-file fit (compute GPU faults), `825523d2eac` VK_KHR_shader_quad_control, `c7fed8e8b2d` 09-08 `VALVE_buffer_device_address_allocation_alignment`, `c6b3e52a9e5`/`30e8e9d6810` 09-14 drirc DEVICE_LOCAL-only memory type (RDR2's FSR2 backend rejects UMA heaps — a class of "context creation fails on UMA" bugs).

**26.2.x backports our pin lacks (29, matched by subject):** the gen8 TEX_LINE_OFFSET, XFB/query sync trio (`aa91556e1d0`, `542da306f0b`, `38aadf54197`), **GPL set-layout stitching `bc35402ffed`** (pipeline libraries → DXVK/vkd3d), pipeline-cache feedback bit, `4c37287e088`, sparse merge (26.2.3 only), plus FDM/a5xx items (irrelevant). The 13 pre-08-09 fixes (LRZ WFI `04e04490ddf`, MSM_SUBMIT_SYNCOBJ `ce8a5fb58b9`, gmem sync2 …) we already have.

**Armada mesa patches:** 0002 a830 chip-id adds KGSL/rev-0001 ids; main still has only `0xffff44050000` (+ KGSL 0x44050001) — we run on `0xffff44050000` under msm, not needed. 0003 bindless-UBO was already trialled and dropped.

**Recommendation:** next one-variable pin bump = mesa main ≥ `73cd30791b1` (09-14) benched with `tools/ab`; if a stable tarball is preferred, **26.2.3** carries TEX_LINE_OFFSET + sparse-merge + GPL stitching but *not* `d286f87b164` / `118ec7f45b1` / `189ee82449f`. Do not pair with the gamescope bump in the same A/B.

## 3. FEX-Emu

- **FEX-2608** `e869aa644` (2026-08-05), **FEX-2609** `395b132f3` (2026-09-08); 588 commits since 2607. **Our four patches apply cleanly to FEX-2609** (`git apply --check`, no errors).
- **Unaligned atomics:** Armada `0505` = Billy Laws "arch: arm64: Implement unaligned atomic emulation/backpatching" (kernel; Armada `3e7fe17` 09-18, PR #473). The FEX side — `prctl(PR_ARM64_SET_UNALIGN_ATOMIC 0x46455849, EMULATE|BACKPATCH|STRICT_SPLIT_LOCKS)` in `FEXInterpreter.cpp:332-346`, config `KernelUnalignedAtomicBackpatching` default true — **is already in our FEX-2607** (added 2026-02-26, PR #5331). Nothing in 2608/2609 changes it. So K13 is purely a kernel item; today unaligned LOCK ops go through SIGBUS + FEX's `UnalignedHandlerType` backpatch to half-barrier atomics.
- **2608:** SVE XAR SHA1, VMOVMASKPD/PS, VirtualProtect on win32 (ARM64EC), 48-bit-VA allocation-region overwrite fix, inactive JIT guard pages, AVX signal state save/restore, WFE spinloops (WINE), clone thread-tracking fix. **FEXInterpreter binary removed** (`523bbef03` 07-09; 2609 installs only `FEX`) → **`packages/pocknix-decky/pocknix-decky-run:27` `exec /usr/bin/FEXInterpreter` and `pocknix-decky-loader.service` break on any 2608+ bump** unless changed to `/usr/bin/FEX` or a symlink is added (no symlink in our fex-emu PKGBUILD).
- **2609:** flag/behaviour fixes, deadlock fixes, PMULHRSW 2x, faster "full" SMC detection (Unity), less JIT lock contention across threads, unixlib fallbacks removed (Wine), **disk cache** opt-in `FEX_DISKCACHE=1` (FOZ under `~/.cache/fex-emu/`, unbounded, "disable with thunk relocs for now" `5a68359f3` — so inert for thunked code on our thunks build), thunks `a31234758` new PV paths, thunkgen clang-22 fix. 32-bit: `635befb4c` BLSMSK/BLSR CF. **TSO: nothing new.**
- **RootFS** (`rootfs.fex-emu.gg/RootFS_links.json`): ArchLinux **2026-08-11** (ero `82c0c5f15edf59d2`, sqsh `23350f949fc1413d`), Ubuntu 24.04 2026-08-11, Fedora 44 2026-08-11 (new), Fedora 43 2026-01-20. Ours is Arch 2026-01-08 with a 26.1.5-1 x86 turnip overlay; a bump is optional and must keep `_mesaver` = host mesa.

## 4. Valve / SteamOS / Holo Core / Collabora

- **gitlab.steamos.cloud** `holo` group (id 49) public projects: steamos-manager (09-18), dirlock (09-18), linux-cec (09-14), dmemcg-booster (08-05), **holo-core-aarch64-preview** (id 1471: source import `1a6f6e90` 06-02, last commit `67f0d559` 06-10 — no activity since), cec-audio-control, powerbuttond. `holo/holo`, `gamescope-session`, `jupiter-hw-support` are 404 (not public); `jupiter` group only has wireplumber/neptunefw-builder/vulkan-examples.
- **steamos-manager `6b6236c6` 09-10 "hardware: Start work on device-tree based detection"**: adds `DeviceTreeMatch {compatible, present, matches}` against `/proc/device-tree`, and `data/devices/steam-frame.toml`: `dt.compatible = "qcom,sm8650"`, `dt.present = ["board-info/board_revision"]`, device `steam_frame`, variant `Deckard`, OUI `e0-31-9e`. First DT-keyed device in Valve's manager — the path by which a `qcom,sm8750` device could be a first-class device later. Also `fd665dae` (validate manager messages not from a Steam game), `dfb4d435` default WifiBackend.
- **Steam client ARM64 out of beta**: @HardwareSteam post 2082139927228150032 = **2026-07-28 16:23 UTC** ("went out of beta last night… good progress for other devices that people could potentially put SteamOS on"). Client notes since (ISteamNews app 593110 + SteamClientBeta RSS, Aug 3 → Sep 18): **no ARM64/FEX/Frame-labelled line**. Adjacent: Sep 9 beta — compatibility-tool dropdown always visible + aliases ("Proton Stable"), SteamOS unverified-HW dialogs on desktop Linux; Sep 16 — fixed crash regression in native Linux games.
- **Valve Proton** `proton-11.0-2` (08-21): "Updated to FEX-2607" — the Steam-shipped "Proton 11.0 (ARM64)" now matches our FEX pin.
- **SteamOS 0.3.0 for Steam Frame** (app 4165890, 2026-09-17, stable): "Multiple improvements to graphics performance (Mesa)", "Vulkan layer fixes for increased game compatibility", Playable criteria now any resolution (was 1440p), faster charging while off/sleeping, stability under high load. No versions given. SteamOS 3.9.0/3.9.1 Preview (Deck, 08-29/09-14): kernel 7.2, **packages renamed `steamos-` → `holo-` with aliases**, wpa_supplicant default, hibernation prelim — the rename will show up in the next Holo Core mash.
- **Collabora**: 09-10 Valentine Burley "Mesa on Android: How we brought Turnip, SkiaVK, and Cuttlefish to CI" — Turnip Vulkan 1.4 conformant on Adreno 7xx (1.3 on 6xx), first Mesa driver with Android conformance, generic multi-queue emulation (emulated queue → primary `driver_submit` under a shared mutex), "will power … Steam Frame"; nothing a8xx. Aug–Sep listing otherwise: Tyr/Mali, RK3588, Kernel Recipes, IBC, SIDO, Chrobalt. **No Holo Core / SteamOS-arm64 post since the 07-18 preview announcement.**

## 5. CachyOS Proton

Latest **`cachyos-11.0-20260703-slr`** (published 2026-07-22), bugfix over our 20260702: `vkd3d-low-latency` option (`PROTON_VKD3D_LOWLATENCY=1`), `DXVK_HUD` default removed (it overrode dxvk.conf), d7vk/dxvk-sarek/low_latency_layer/nvidia-libs bumps. arm64 assets present (`proton-cachyos-11.0-20260703-slr-arm64.tar.xz` + `.sha512sum`). Repo commits since are docs only (last `8a8453e` 07-23). No ARM64/FEX-specific items. One release behind, low risk.

## Ranked shortlist

1. **Gamescope 3.16.29 (`8f21264`) for the rotation experiment** — instead of fa0b4d3: Adreno RCAS/SGSR/composite-gate, `2d217a1` format-check fix, Frame menu/focus fixes; 0001/0004 apply, rebase 0006 over `d12ec39`, drop 0005 (→ `38fb50f` native composited rotation / K11 scanout), don't stack ROCKNIX 0007. Watch "Primary plane doesn't support any formats" and the 0008 black-panel signature; enable `drm_cursor_plane` only after scanout works. *With the rotation experiment.*
2. **Mesa pin bump** (main ≥ `73cd30791b1` 09-14, or 26.2.3 tarball) for gen8 TEX_LINE_OFFSET `7ea5e51c8a3`, gen8 multi-plane base `d286f87b164`, 32B rollover `118ec7f45b1`, sam.s2en fault quirk `189ee82449f`, sparse merge `73cd30791b1`, GPL stitching `bc35402ffed`. *One variable, benched, separate from #1.*
3. **U2 sparse-sync A/B** — Armada patch applies (offset -8); upstream untouched; the mesa-side lever for the QAM freeze family, to run alongside #1's menu fixes. *With/after #1.*
4. **FEX-2609 bump readiness** — patches apply clean; fix `pocknix-decky-run` `/usr/bin/FEXInterpreter` → `/usr/bin/FEX` (and the service description) first; then try `FEX_DISKCACHE=1` for JIT stutter. *After release.*
5. **Kernel K13 (Armada 0505 unaligned-atomic emulation)** — FEX side already in our 2607, so it is kernel-only; still 2 days old and unreleased at Armada. *After release, A/B, once Armada ships it.*
6. **Routine bumps**: proton-cachyos 20260703, FEX Arch rootfs 2026-08-11 (keep `_mesaver` = host). *After release.*

## Nothing new

- Holo Core aarch64 preview: no repo activity since 06-10, no new mash (matches the earlier sweep).
- Collabora on SteamOS/Holo Core arm64: nothing since 07-18.
- Steam client release notes (stable + beta, Aug 3 → Sep 18): no ARM64/FEX/Frame lines.
- Mesa main turnip: no UCHE-fault or a6xx+ hang commits since bab34da4.
- FEX TSO: no changes in 2608/2609; FEX↔kernel unaligned-atomic prctl unchanged since Feb.
- gitlab.steamos.cloud gamescope-session / jupiter-hw-support / holo: not public (404).
- CachyOS Proton: no release since 07-22.

Sources: [ROCKNIX/Armada sweep doc](docs/upstream-sweep-2026-09-20.md), [Valve gamescope](https://github.com/ValveSoftware/gamescope), [mesa GitLab](https://gitlab.freedesktop.org/mesa/mesa), [FEX-2609](https://github.com/FEX-Emu/FEX/releases/tag/FEX-2609), [FEX-2608](https://github.com/FEX-Emu/FEX/releases/tag/FEX-2608), [FEX RootFS](https://rootfs.fex-emu.gg/RootFS_links.json), [holo-core-aarch64-preview](https://gitlab.steamos.cloud/holo/holo-core-aarch64-preview), [steamos-manager](https://gitlab.steamos.cloud/holo/steamos-manager), [Steam Hardware ARM64 post](https://x.com/HardwareSteam/status/2082139927228150032), [SteamOS 0.3.0 for Steam Frame](https://steamcommunity.com/games/4165890/announcements/detail/711161056325533926), [Collabora Mesa on Android](https://www.collabora.com/news-and-blog/news-and-events/mesa-on-android-how-we-brought-turnip,-skiavk,-and-cuttlefish-to-ci.html), [Collabora Holo Core preview](https://www.collabora.com/news-and-blog/news-and-events/building-an-arch-linux-aarch64-port-for-holo-core.html), [proton-cachyos releases](https://github.com/CachyOS/proton-cachyos/releases), [Valve Proton 11.0-2](https://github.com/ValveSoftware/Proton/releases).
