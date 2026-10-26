# Upstream sweep, 2026-09-27 -> 2026-10-02 (+ Qualcomm drivers, the SteamOS-ARM-Handhelds port)

Cliff's questions: has Qualcomm shipped Linux drivers for what's missing, has anyone improved AAA fps,
what is hashtagbasit's "SteamOS ARM on the 8 Elite" doing, and is it time to re-pin.
**Decision (Cliff, 10-02): park all of this until the headphone jack and the basic RP5 work are done.**
Nothing here is applied. Patches are staged (paths at the end); binaries are archived locally.

Method: two research agents (gh/GitLab APIs, kernel.org cgit, Valve mirrors, web search) plus my own
unpacking of Valve's hotfixes packages and a read of hashtagbasit's source. Dates are from the sources.

## Bottom line

- **No measured AAA fps gain on 8 Elite Linux since August.** Our Cyberpunk numbers (22.1 native /
  30.6 FSR-P / ~56.7 presented with lsfg, 720p Low, `docs/cyberpunk-bench-plan.md`) are still the only
  rigorous ones. Armada "40-50 fps" videos state no method and fit frame-generated output.
- **Qualcomm has not released a closed Linux GPU driver for the 8 Elite.** It *is* now writing the open
  one: Adreno 830 kernel support (Jie Zhang, Akhil P Oommen) landed in msm-next 09-26 for Linux 7.4.
- **Re-pin timing:** around Linux 7.4 (~December) + mesa 26.3 (rc1 due 10-14). That's when we can drop
  ROCKNIX's a830 patch instead of stacking on it. Until then: a backport batch on 7.1.3 + experiments.

## 1. Valve / Qualcomm

**Valve.** Deck: SteamOS 3.8.28 stable 09-25, 3.9.2 still beta. ARM: Steam Frame (SM8650) shipping
since 09-18; Frame OS 0.3.0 stable 09-17, 0.4.1/0.4.2 beta 09-26/29; Frame uses Turnip. 3.8.28 adds
"initial gamepad support for AYANEO Pocket S2" (SM8650 handheld), and the Frame kernel carries Pocket
S2 dtbs: Valve may be testing a Snapdragon handheld (inference). No Frame kernel source; no new Holo
Core mash (preview still mash-20251118.3, deckard still mash-20260305). Proton 11.0-2 (FEX-2607).

**Qualcomm-authored, queued for 7.4 (all staged below):**
- `2c94d177` drm/msm/a8xx: Add support for Adreno 830 (+ binding `ab20121e`). **Trap:** matches chip
  id 0x44050001; our kernel reports 0x44050000 (hashtagbasit's note says ROCKNIX's 7.2.0 kernel reports
  0xffff44050001). Moving ids = kernel table + DT compatible (our 0038) + mesa >= `2061a5ee` together.
- Register-list diff vs our 0049 (`a830-reglist-ours-vs-upstream.diff`): ours lacks
  `RB_CCU_DBG_ECO_CNTL=0x2200` (HW workaround), the IFPC-restore entries `SP_HLSQ_DBG_ECO_CNTL`,
  `RBBM_PERFCTR_CNTL`, `CP_PROTECT_GLOBAL(47-62)`, `TPL1_BICUBIC_WEIGHTS_TABLE(0)` in the pwrup list, and
  speedbins. Candidate for unexplained a830 instability. Rebase 0049 onto it, keep our chip id.
- `db6a2e4a` honor perfmode_bw threshold on A8x (power; our threshold 8171875 vs upstream 10687500 starts
  to matter once this is in), `eab0aff8` RPMH dependency votes, `128a0edd` secondary rail in ARC votes
  (a6xx family: RP5 too). 3-8 lines each.
- SM8750 GPU DT nodes + GPU cooling (`9e39531ce39a`, `c4dc1775c772`, `d5eee07a78`, `c9cf34cb19`; staged:
  `f695831a` GPU clock & IOMMU). Would replace our 0038 on a 7.4 base.
- PCIe WAKE# polarity: `eec036783b` (sm8750), `adf55ad006` (sm8250). Our Odin DT (0046) still has
  `wake-gpios ... GPIO_ACTIVE_HIGH`; Armada flipped the same in PR #545. Our own one-line DT edit.
- Mesa: a830 chip id !43878 (`2061a5ee`, 08-19, after our 08-09 pin; not in 26.2.4); !44352 split large
  indirect draws (open); !43940 a8xx CTS fixes (draft; 38 CTS fails remain).
- Contribution split, freedreno/turnip since 08-01: 107/333 commits from Qualcomm addresses (mostly Rob
  Clark, Dmitry Baryshkov), 129/333 Igalia.
- Snapdragon X2 laptops: Qualcomm "upstream-first" Linux EDP (Debian 13 first, production Nov 2026).
  Laptops only, same GPU family.
- Still missing on SM8750: conformant A8xx Vulkan, UE5 fixes, WCN7860 wifi firmware/driver upstream, an
  upstream Odin 3 DT, upstream sleep-power work. Iris video decode is already mainline (since 2026-01).

### Qualcomm's closed Adreno driver in Valve's hotfixes repo (my unpacking, 10-02)

`https://holo-packages.steamos.cloud/archlinux-deckard-hotfixes/` carries two builds:
- **`qualcomm-linux-graphics-driver-20260619.1-1`** (built 06-20): libgsl opens `/dev/dri/renderD128`
  and uses only **upstream drm/msm** ioctls (decoded from the binary: MSM GET_PARAM, GEM_NEW/INFO/SUBMIT,
  SUBMITQUEUE_NEW/CLOSE, WAIT_FENCE, PRIME, syncobj incl. timeline; no VM_BIND, no KGSL). GPU name table
  includes Adreno 650, 740, 830. libvulkan_adreno: 198 extension names incl. robustness2,
  transform_feedback, descriptor_buffer, graphics_pipeline_library, maintenance5/6. GBM wants
  `/dev/dma_heap/system`.
- **`qualcomm-linux-graphics-driver-kgsl-20260908.2-2`**: Qualcomm LE build (`LE.PRODUCT.2.1 KAILUA`),
  KGSL ioctls only; tmpfiles links `/dev/kgsl-3d0 -> renderD128`. Valve's 7.2 kernel has a KGSL-uAPI
  shim inside drm/msm (`msm_kgsl.c`, 51 `kgsl_*` symbols in System.map; no config option, source
  unpublished). Unusable on our kernel without writing that shim.
- **Licence:** labelled Apache-2.0, but NOTICE: use is "subject to the terms of your license from
  Qualcomm Technologies". Not redistributable. Local testing only, never in our repo or images.
- **Experiment (later):** our sm8750 kernel needs `CONFIG_DMABUF_HEAPS=y` + `CONFIG_DMABUF_HEAPS_SYSTEM=y`
  (Valve has both; we have neither). Then the June build in a side dir, `VK_ICD_FILENAMES` -> vulkaninfo,
  vkcube, one DXVK game vs Turnip. Uses: (a) Odin AAA ceiling (driver vs emulation bottleneck);
  (b) RP5 DXVK freeze: freezes on Qualcomm's driver too = kernel, doesn't = Turnip. Unverified that it
  even initialises on mainline msm.

## 2. Performance / pull candidates

Note: in-game x86 code runs on **Proton's bundled FEX**, not `packages/fex-emu`
(`pocknix-proton-wrapper`). proton-cachyos 20260702's FEX submodule = 110313e (06-30). A FEX package
bump alone does not change game performance.

Ranked (none applied):
1. **Armada 0619, msm submitqueue priority** (PR #574, merged 09-29). The kernel inverts priorities, so a
   game's Turnip queue outranks Xwayland/steamwebhelper/mangoapp: "Quick Access Menu opening without being
   drawn and Steam's main loop stalling on Xwayland". Very likely our issue #1 (controls dead after Steam
   menu/QAM). Mainline 7.3-rc5 still inverted. Applies to 7.1 with offsets, no overlap with our patches;
   both SoCs. Risk: small fps cost while overlays draw; bench it.
2. **Turnip autotune on the current pin, no rebuild:** `TU_AUTOTUNE_ALGO=profiled|prefer_gmem|
   prefer_sysmem`, `TU_AUTOTUNE_FLAGS=big_gmem`. Never tried. Per game via launch options only (a bad value
   in /etc/environment kills gamescope). ROCKNIX PR #3388 (open) works the same gmem/sysmem question; its
   three autotune patches are staged (rx-0003 says "Assisted by: Gemini").
3. **vkd3d-proton 9840cbf737** (09-16): no CPU-side waits on single-queue drivers ("mostly relevant on
   Turnip"); ours (3dfc6f07, 07-10) is 203 commits behind. Cheapest A/B: Valve Proton Experimental
   bleeding-edge 10-01 (vkd3d + DXVK 09-30, FEX main 09-28 with code cache). Our proton-prep never offers
   Experimental and our FEX profiles won't apply; its toolmanifest may need the 11.0-ARM64 treatment.
4. **RP5: mesa !19316** "Clear UBWC flags buffer on transition from UNDEFINED": an A650 UBWC hang that
   freezes "the entire machine and causing an insta-reboot". Matches our UBWC-triggered DXVK freeze;
   untested here. 2022 MR, needs a rebase. Staged.
5. **ROCKNIX ABL v1.2** (09-30); v1.1.9's asset is gone. `rocknix-abl-releases.tsv` needs the four 1.2
   rows (installer identification). ELF sha256 (258048 B each): SM8750 `cd0f8718685ff96b6932a8cac7195997
   af87929b03570c30fe6cdec58745e63a`, SM8250 `041778d622bc1a667fa56537ad92cfa9e9519c8f1ca4784772244911816af0ef`,
   SM8550 `8db99d7f84002e04e7b6d4ba8427e8229da553233faeb9944509cf5d1f2d4141`, SM8650 `49a479c42c84f26bafa75b
   727c85967d19eb6756697dc532051c436bd60cf998`; tarball `4fcf983aff6a...` (verified locally). Kit stays on
   1.1.8. The tsv is user-visible: adding rows means a respin.
6. **msm-next backports** (power/memory): `db6a2e4a`, `eab0aff8`, `128a0edd` (see section 1), `bbe4401e`
   THP for GEM buffers ("more than 2x speedup on darktable"; game effect unmeasured; THP is on in our
   config), `8eeca96a` shrinker-blocking modparam (stutter under memory pressure). Apply to plain 7.1;
   our 0049/0051 touch the same files, so check against our tree.
7. **Mesa pin: not for fps.** For correctness: main `8ea6e9dd41` (10-01) or 26.3.0-rc1 (10-14): the four
   gen8 fixes, LRZ stencil !44200, a830 chip id, rotated copy !44689 (merged 10-01). 26.2.4 has none of
   the gen8 fixes. Our 0002 needs a rebase, 0004 can go (msm backend refactor). 09-01 main lost 3.2%.
8. **FEX: any bump goes to 2609.1** (fixes 2609's ldconfig segfault at Steam start, FEX #5942). The
   FEXInterpreter-removal blocker (`pocknix-decky-run`) still applies. No 2610 yet.
9. **Five-minute test:** Expedition 33 with `tu_enable_ssbo_emulation=true` (mesa !44325 + vkd3d-proton
   PR 3280 turn it on for UE5). May or may not touch our black screen.

Watch: gamescope 3.16.31 (09-27; fixes 3.16.30 "no visible window"; use it for the rotation test);
steamos-manager !82 (GPU clocks + platform profiles for ARM); Nova-Deck TEO idle governor, a 12%-cheaper
composite pass, Lepton working, 7.2.8 on four boards; DXVK 3.1.1 tiler DX11 work (not in proton-cachyos);
vkd3d-proton Elden Ring denormal fixes; Armada 0505a unaligned atomics (#582) says SM8550+ does these in
hardware (so the kernel side is RP5-only; staged under sm8250); Armada dropped its night-mode workaround
(Steam beta fixed it; our gamescope 0007 is harmless). Nothing new: proton-cachyos (20260703), Proton 11.0-2,
vkd3d-proton v3.0.1, FEX RootFS, InputPlumber 0.81.0, Decky 3.2.9, MangoHud 0.8.4, ROCKNIX SM8750 tree,
MaSieS4Fun, Steam beta 09-27/29.

## 3. hashtagbasit/SteamOS-ARM-Handhelds (read at 5ddfd5c, 10-01)

Unofficial port of **Valve's Steam Frame OS image** to Snapdragon handhelds (repo created 09-24, 136 stars;
author owns only a KONKR Pocket FIT/SM8650; Odin 3 support is contributor Chazmus's PRs #14/#16/#17).
Odin 3 beta 1 published 09-30 (`v1.3-odin3-beta1`, 3-part 7z, ~4.6 GB, ~30 downloads).
- **Base:** `make-steamos-sm8750.sh` downloads the Frame RAUC bundle `deckard-20260925.6175226-0.5.0.raucb`
  from `steamdeck-images.steamos.cloud/vr/` and reassembles the full rootfs from Valve's public casync
  chunk store (`scripts/extract_rootfs.py`). Our 09-24 survey said this was possible but untried; it works.
  The image therefore contains Valve's proprietary Frame packages (deckard-hw-support, Steam client under
  the SSA, and, unless removed, steamos-customizations-deckard with its embedded CI credentials).
- **Odin 3 kernel:** ROCKNIX's prebuilt 20260901 release (7.2.0) KERNEL + modules + firmware, unchanged
  (`external-and-mods/kernel-sm8750/extract-rocknix.sh`); only the cmdline is patched.
- **Mesa:** 26.2.3 + a830 chip ids (`0003-freedreno-a830-chip-ids.patch`), Zink for GL. Lacks the
  main-only gen8 fixes we carry. On SM8550 Valve's Frame Mesa shows nothing on screen, so they replace it.
- **Rest:** VR services masked, handheld RUNSTEAM.sh, InputPlumber yaml, odin3d fan/profiles daemon,
  UI scale seed, Decky, lsfg-vk arm64 layer, stubbed steamos-update. Windows games: ARM64 Proton + FEX
  (same model as ours).
- **vs Holodor:** we build the SteamOS layer on Valve's public Holo Core base and redistribute only open
  source; our kernel is our own 7.1.3 with ROCKNIX + Armada + our fixes; Steam is bootstrapped on device;
  pacman OTA. Nothing Valve ships targets SM8750, so on the Odin 3 both projects replace the same parts.
- Ideas from their SM8650 HOW-IT-WORKS (unproven on SM8750): GPU devfreq polling 16 ms (vs 50), fan curve,
  uclamp game-thread boost (`CONFIG_UCLAMP_TASK` is off in our config too), GPU OPP at TURBO_L1.
- Valve hardware packages (kernel, firmware, u-boot/bootfw, hw-support, charger/fan/LED/EEPROM/FPGA/
  power-monitor, audio-config, VR Vulkan layers) are Frame-board-only: no use on SM8750 or SM8550.

## Where things are

- `kernel/sm8750/patches-staged/upstream-2026-10-02/`: Armada 0619; msm-next 2c94d177 (a830), db6a2e4a,
  eab0aff8, 128a0edd, bbe4401e (THP), 8eeca96a; qcom eec036783b (wake), f695831a (GPU cc/IOMMU);
  `a830-reglist-ours-vs-upstream.diff`.
- `kernel/sm8250/patches-staged/upstream-2026-10-02/`: Armada 0505a, Armada 0619, msm-next 128a0edd, qcom
  adf55ad006 (wake).
- `packages/mesa-next/patches-staged/upstream-2026-10-02/`: !19316 (2 commits), ROCKNIX PR #3388 autotune
  rx-0001..0003.
- Local only, not in git (`~/odin3-backups/upstream-2026-10-02/`): ROCKNIX ABL v1.2 tarball + ELFs, both
  Qualcomm driver packages, `linux-72-deckard-headers` (Valve kernel .config + System.map).

## Suggested order once the jack + RP5 basics are done

1. Kernel backport batch on 7.1.3: Armada 0619 (issue #1), a830 reglist rebase of 0049, db6a2e4a +
   eab0aff8 + 128a0edd, Odin wake-gpios active-low. A/B with the sleep-power harness and `tools/ab`.
2. Experiments, no re-pin: Turnip autotune; Qualcomm June driver vs Turnip (both devices); !19316 on
   the RP5; Expedition 33 SSBO emulation.
3. ABL v1.2 tsv rows with the next respin.
4. Re-pin around 7.4 + mesa 26.3 (drop ROCKNIX 0049/0038 for upstream; chip id move done as one change).

Sources: [hashtagbasit port](https://github.com/hashtagbasit/SteamOS-ARM-Handhelds),
[Odin 3 beta 1](https://github.com/hashtagbasit/SteamOS-ARM-Handhelds/releases/tag/v1.3-odin3-beta1),
[msm 2c94d177](https://gitlab.freedesktop.org/drm/msm/-/commit/2c94d177a927a25d3eb111fe83694b5f84239069),
[msm db6a2e4a](https://gitlab.freedesktop.org/drm/msm/-/commit/db6a2e4a7ebd),
[msm eab0aff8](https://gitlab.freedesktop.org/drm/msm/-/commit/eab0aff8965e),
[msm bbe4401e](https://gitlab.freedesktop.org/drm/msm/-/commit/bbe4401e118c),
[SM8750 GPU DT](https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/commit/?id=9e39531ce39a98a77ddcf58f838a50dbf164092c),
[PCIe wake sm8750](https://git.kernel.org/pub/scm/linux/kernel/git/qcom/linux.git/commit/?id=eec036783b),
[Armada PR #574](https://github.com/armada-os/armada/pull/574),
[Holodor #1](https://github.com/transentient/holodor/issues/1),
[vkd3d-proton 9840cbf737](https://github.com/HansKristian-Work/vkd3d-proton/commit/9840cbf737),
[Proton FEX cache](https://github.com/ValveSoftware/Proton/commit/09d3d6e5f6),
[mesa !19316](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/19316),
[mesa !43878](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/43878),
[mesa !44352](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/44352),
[mesa !43940](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/43940),
[mesa !44325](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/44325),
[ROCKNIX #3388](https://github.com/ROCKNIX/distribution/pull/3388),
[ROCKNIX ABL v1.2](https://github.com/ROCKNIX/abl/releases/tag/v1.2),
[FEX #5942](https://github.com/FEX-Emu/FEX/issues/5942),
[gamescope 6867f50987](https://github.com/ValveSoftware/gamescope/commit/6867f50987),
[steamos-manager !82](https://gitlab.steamos.cloud/holo/steamos-manager/-/merge_requests/82),
[XDC Turnip](https://indico.freedesktop.org/event/12/contributions/543/),
[XDC Qualcomm](https://indico.freedesktop.org/event/12/contributions/570/),
[Snapdragon X2 Linux](https://www.gamingonlinux.com/2026/09/qualcomm-announce-snapdragon-x2-series-will-support-linux/),
[SteamOS 3.8.28](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1844751498222971),
[Frame OS 0.3.0](https://steamcommunity.com/games/4165890/announcements/detail/711161056325533926),
[Valve hotfixes](https://holo-packages.steamos.cloud/archlinux-deckard-hotfixes/).
