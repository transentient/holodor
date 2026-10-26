# Upstream sweep, 2026-09-24: ecosystem reaction + delta since 09-20

Read-only. Companion to docs/upstream-sweep-2026-09-20.md and -valve.md; nothing below repeats them.
Clones in `/tmp/claude-1000/-home-cliff-projects-holodor/f47c1c0b-2197-4c3c-9518-2bd7cb350919/scratchpad/sweep/`
(`armada`, `rocknix`, `abl`, `gamescope`, `mesa`, `fex`, `steamos-manager`, `novadeck`, `sm8550`; logs and PR/issue
bodies in `*.txt`). The deckard package tree and the SM8550 port are covered in depth by the other agent; here they
appear only where a peer distro consumes them. Our pins as of release 20260923e: kernel 7.1.3 (linux-pocknix-sm8750
pkgrel 26), gamescope `4286887`, mesa-next `bab34da4`, FEX-2607, proton-cachyos 11.0-20260702, iwd for Wi-Fi,
no steamos-manager (pocknix-steamos-shim stubs).

## 1. ArmadaOS (github.com/armada-os/armada, 91 commits 09-18..09-23; no release since 20260915)

**Is Armada consuming deckard?** Selectively, by source tarball and by GitLab branch, not by rebasing:
- **steamos-manager, real one** — `ef6ccc0` 09-21 "add basic steamos-manager package" + `3bcb03a` 09-21 "replace
  python shim with steamos-manager" + `2270419`/`deaf3b7`/`809555b` (09-22/23). Base = holo/steamos-manager main
  `8e2883d` (09-16, v26.4.1) with Valve's **public `arunr/steam-frame` branch** rebased on top (0001-0009:
  "Initial support for Steam Frame", platform-profile manager, custom platform profiles, devfreq GPU driver,
  gpufreq_limit, GPU manual-clock minimum; authors Arun Raghavan and Matthieu Bucchianeri, 05-14..08-26). Armada
  adds `devices/sm8750.toml` (`ayn,odin3` -> device `ayn_odin_3`, variant `Odin3`; `konkr,pocket-fit-elite`),
  `[cpu_scaling] driver="none"`, and remotes `PerformanceProfile1`/`GpuPerformanceLevel1`/`CpuScaling1` relayed
  over D-Bus to armada-powerd (`/etc/steamos-manager/remotes.d/armada.toml`). Own patches: 0010 CpuScaling1 via
  remote, 0011 "inputplumber: only manage target devices when configured" (DeckService races their controller
  service and forces `[deck-uhid]`, dropping keyboard/mouse targets), 0012 "always write wpa_supplicant as the
  backend" (Steam derives the backend from `steamos_wifi_force_wpa_supplicant` and **writes `iwd` on every launch
  when that setting is off** — with the real manager they had to pin it). `809555b` hands session switching
  (game/desktop/mobile default) to steamos-manager; `session-control` stays as a boot-time fallback.
  *Why it matters:* first peer distro to run Valve's own manager on an SM8750 device with a DT match; the
  `arunr/steam-frame` branch is the public Frame device layer (devfreq GPU clocks, platform profiles) and is what
  our pocknix-steamos-shim stubs stand in for. Also a direct answer to why Steam might flip our Wi-Fi backend
  once a manager is present (we are on iwd, which is the client's default write).
- **Valve NM/wpa_supplicant post-resume patches** — `b6614ba` 09-22 (#513): NetworkManager 1.58.1 + Valve's
  "scan only last-associated freq after resume" (NM MR 2514, taken from `steamdeck-packages.steamos.cloud/
  archlinux-mirror/sources/holo-3.9/networkmanager-1.58.0-1.7.src.tar.gz`), and a wpa_supplicant 2.11 package with
  Valve's two rescan patches (hostap list Aug 2026: "avoid redundant 6 GHz rescan after resume", "no forced
  rescan after restricted scan" — the radio comes back "in a new regulatory domain on every s2idle resume").
  Drops iwd from base ("never used, kernel config doesn't support it"). *Why it matters:* fast Wi-Fi reconnect
  after s2idle is exactly our resume path; we are iwd so the NM/wpa patches don't apply directly, but the
  regdomain-reset-on-resume observation ties to K3c and to our roam/fw-crash log.
- **gamescope:** they did **not** take deckard gamescope. `cb3261a` 09-18 bumped to 3.16.29-ogc1 (terra
  `7989f35`), **reverted 09-20** (`a0bd432`, #494, no reason in the PR; same-day companion `a765987` "use shader
  rotation for bottom screen gamescope — inherited hardware rotation breaks Vulkan display setup during DRM lease
  handoff"). Back on terra `16ede97` (3.16.28-ogc). Their 21-patch stack (EDID synth, gamma22 HDR, DRM lease v1,
  LUTDMA SDR CM, arm64 virtual white, libliftoff primary-plane stacking) is unchanged.
- **mesa** 26.2.3 (`4e4db15` 09-18, unchanged since); **FEX-2609** `395b132` (`fae8404` 09-18). Neither from
  deckard.
- **Kernel:** 7.2.6 landed for good. Timeline: `c9b6831` 09-18 bump -> `659dc6b` 09-19 revert -> `91e78c7`
  09-19 re-apply + `c30f994`/`b0abd0a` fixes -> #487 merged 09-20. The 7.2.6 breakage was **Wi-Fi/PCIe on
  SM8750**: 7.2.6 includes `366a540432a3` "arm64: dts: qcom: sm8750: Fix the PCIe iommu-map entries" (five-cell
  entries) and two parsers still assumed four cells — `0514-PCI-qcom-honor-iommu-map-cell-count` (Mani
  Sadhasivam, lore 20260907143349) and Armada's own `0514a-of-property-honor-iommu-cells-in-iommu-map-devlinks`
  ("on the Odin 3 DTB phandle 0x100 points to a CoreSight endpoint, so PCIe probing waited on CoreSight; boot log
  shows the missing PCIe host and Wi-Fi"). Plus `0048a` DSI byte-clock rounding after PLL reparent (Dmitry
  Baryshkov, torvalds `2028280686f4`, "DSI 6G v2.9 hosts SM8650/SM8750 ... PLL programmed to a wrong frequency,
  breaking the panel"). 7.2.6 also let them drop 0050 (gxclkctl gdsc), 0062/0065 (aw99706) and gut 0517.
  *Why it matters:* the two iommu-map parsers and the DSI rounding are **mandatory the day we go 7.2.6+**
  (alongside ROCKNIX 0606 noted 09-20). Not applicable to 7.1.3 (our DTS still has the old four-cell map).
- **K13 unaligned atomics:** `3e7fe17` 09-18 (#473) merged 09-19, still **not in an Armada release** (last
  20260915). See the Nova-Deck bug in section 4: Armada's 0505 is bylaws' patch unchanged and **lacks the Load128
  exception-table fix**.
- **Sleep work since 09-18:** `9dbff07` 09-22 sleep diagnostics rewritten as `armada_sleep_debug.py` (1391 lines,
  kernel tracing, opt-in from Decky #500, keeps 10 reports in ~/Documents/sleep-logs); `b6614ba` Wi-Fi reconnect
  above; **#478 open** (xcqq, 09-23) "pocket-fit-elite: add PCIe suspend OPP" — SM8750 AOP can fail to return
  after final cluster collapse without a nonzero DDR/LLCC sleep-set vote; "**Odin 3 suspends without it, so the
  shared SM8750 OPP table is left unchanged**" (refs #403). No new Odin 3 resume/dead-controls patches: their
  0508 (rsinput pm resume), 1005 (quiesce MCU across sleep), 1006 (reassemble UART frames), 0513/1201 (geni IRQ
  mask), 0519 (ucsi clear USB role) all predate 09-18 and **we already carry all of them**. Nothing new for our
  dead-Steam/QAM-after-s2idle issue.
- **Odin 3 issues:** #350 "internal install hangs at Starting Steam" (regression after 20260817, second user
  09-23 after a forced update); #508 gyro — JPyke3 09-22 "working on the preview branch", justradical: "not yet,
  drift/calibration issues"; #518 brightness hotkey broken after 20260915; #509 lsfg-vk no frame-gen on Odin 3
  (user has Lossless Scaling installed; unresolved). #497 KONKR dual boot: answered "use the ABL boot-mode/source
  menu". Discussions are disabled on the repo; armadaos.dev has no news page (09-18 commits only add a generated
  downloads page + release monitor).
- **Other:** `dce70c1` 09-20 default perf profiles now conservative/ondemand ("schedutil doesn't provide
  consistent frame times"); `918ab54` removes the CPU-realtime toggle ("several classes of user issues"); `4a4a479`
  bootc rebase helper; `119ff15` Armada Tools recovery app (SSH toggle, rollback, Steam repair); `1751e87`
  ARM64EC OptiScaler in their store; #525 open LUKS root + unl0kr; K6 rsinput 250 Hz/deadzone-drop
  (`475b776`/`45b659e`) merged 09-19 via #470, still unreleased; new repo **armada-os/adtbloader** (09-23, dtbloader
  fork: EFI DT loader with "Android DT detection as a fallback for ArmadaOS handhelds when SMBIOS cannot identify
  them", Thor + RP Nova added) — a UEFI/sd-boot path is being prepared, not ABL-based.

## 2. ROCKNIX (distribution `next`, 77 commits 09-17..09-23; abl repo: nothing)

- **SM8750 DTS moved out of patches:** `0b991b0ee6` 09-19/21 (spycat88) "move patch files to dts" — 0046/0047
  (CQ8725S common + Odin 3), 0052 (redriver SS), 0601 (pwm fan sysfs), **0602 (RTC SDAM)**, **0604 (swr1 PCM
  mask)**, 1003 (haptics DTS) are now folded into
  `projects/ROCKNIX/devices/SM8750/linux/dts/cq8725s-ayn-common.dtsi` + `cq8725s-ayn-odin3.dts`; `6cb9859096`
  09-23 moved them under `dts/qcom/`. Patch dir is 58 files. *Why it matters:* our K4/K1b cherry-picks
  (0602/0604) no longer exist upstream as patches; future DTS deltas must be diffed against the whole dtsi, and
  `scripts/sync.sh` (rsync of `patches/linux`) would now silently drop the DTS entirely. `make sync` remains
  unsafe.
- `e2a42167ab` 09-19 (loki666) ar14 panel 144/120/90/60 DFPS modes — Pocket FIT (0055), not the Odin 3 panel. N/A.
- `6a7213eab3` 09-18 DBV cap = K2 (already integrated 09-20).
- `3993c6bb66` 09-22 wifictl: switching networks while already connected returned early; `bc6e32052a` 09-22
  `STEAM_COMPAT_GRAPHICS_PROVIDER` had a `//storage` typo; `9f0286a6c9` SM4450 gamescope Wayland backend (nested);
  `e878bd90dc` reinstall steamrt (U4). None touch our scripts (we have no wifictl copy; grep of packages/ for
  STEAM_COMPAT_GRAPHICS_PROVIDER is empty).
- **installtointernal:** unchanged since f15d4a0 — lines 174-176 still `name ROCKNIX` / `set msftdata on` / `set
  boot on`. Our known issue stands; nobody has told them.
- **ABL:** v1.1.8 still latest; abl repo last commit 08-01.
- **Kernel:** SM8750 still 7.2 (`projects/ROCKNIX/packages/linux/package.mk`); `3336` "rocknix-joypad needed for
  linux 7.3" hints at a 7.3 cycle; PR 3358 open ports rk3566/76 to 7.2.7.
- **Open PRs we track, all still open:** 3049 ucsi drop USB roles over suspend (upd 08-30), 2840 charge bypass
  (09-09), 3171 wcn7860 passive multi-band scan crash (09-15), 3173 wifi country (09-15), 3187 HDMI audio KONKR
  (09-15), 3191 cooling maps (08-18), 3005 Odin 3 SSC accel+gyro (08-30). **3126 "SM8550 deep suspend/resume,
  continued"** (xiaodoudou, upd 09-18) is the one to read: consolidates Armada/Pocknix sleep patches for SM8550
  (USB mode off before sleep cuts resume 14.6->2.8 s; gamepad waits for MCU and reassembles partial frames; Wi-Fi
  chip lockup on immediate re-sleep; standby 4-5 %/h "firmware policy"); explicitly cites Pocknix as a carrier.
  SM8750 gets nothing from it directly, but the USB-role-off-before-sleep result is the same lever as 3049.
- New: 3338 open — `/etc/inputplumber` -> `/storage/.config/inputplumber` persistent overrides; 3351 merged RP5 dock
  DP (phantom NB7VPQ904M retimer, GPIO SBU mux; credits armada #482) — SM8250 only, but the "retimer that never
  reads CHIP_VERSION and binds to nothing" pattern is worth remembering for K10 on the Odin 3.
- ROCKNIX issues: none since 09-18 mention Odin 3 / SM8750 / Steam.

## 3. Valve upstream delta since 09-20

- **gamescope:** no tag after 3.16.29 (`8f21264`). 14 commits on master to `ad2763d` 09-23, all Frame/headless:
  headless sessions via stand-in connector, persisted display-mode list, catch up to next vblank in one step
  (`3b3cced`), `f3b792a` revert "prevent nested clients escaping to host Wayland", `79b1b99` build: disable C++
  modules, `40e991e` nested cursor from mouse-focus Xwayland, legacy mangoapp stream kept for hidden mangoapp
  (`f63959a`). Nothing msm/DRM-rotation/menu. 3.16.29 recommendation from 09-20 stands. Nova-Deck's 3.16.29 bump
  notes (`52781d2`): new `enable_zenity` meson option (default on; fork/execs zenity from the WSI layer's fatal
  path — set false if zenity isn't shipped), and `33b4eff0` moved context in rendervulkan.hpp so patches around
  `struct Layer_t` apply at fuzz 2 silently.
- **mesa main** (`e1f3f37` -> `4487dd7b` 09-22): 49 freedreno commits, **no a8xx/gen8-specific fix**. Rob Clark's
  quirk framework landed 09-18/22 (`a3c6dff6` device quirks section; ir3 quirks renamed to Qualcomm bug ids
  `QCTDD*`; `0d08b96e` dump quirk summary; `9b8447b4` dup magic-regs check) — a830 (`a8xx_gen1`) carries
  `has_salu_int_narrowing_quirk`, `QCTDD10204462=False`, `QCTDD11147232=False`; note the a810 comment "possibly
  also needed for a830 (and all of a8xx): has_fs_tex_prefetch = False — move to a8xx_base if confirmed". Also
  `82b86896` VK_KHR_multiview + Vulkan 1.3 on all a6xx (sw multiview), `5106d00d` A702 resolve, `2f8dc9ea` ir3
  sched kill/bary.f fix, Emma Anholt ir3 src-mod/denorm correctness (`8664e26e`, `64bdcea0`), `4db0b15c` a710/a720.
  **No 26.3 branch/rc**; `staging/26.2` moved 09-21 (100 commits since 26.2.3 incl. `bc9a8437` sparse merge,
  `5398bb2b` lazy-memory capture addr, `7572152e` ir3 quad votes, `421bfb3a` global_offset unsigned; none of the
  four gen8 fixes from the 09-20 list is in it) -> a 26.2.4 is imminent but still won't carry
  `d286f87b164`/`118ec7f45b1`/`189ee82449f`. Mesa pin advice from 09-20 unchanged (main >= 09-14).
- **FEX:** no tag after FEX-2609; 120 commits on main to 09-22. Dominant theme = **DiskCache by Pierre-Loup
  Griffais (Valve)**: relocations within the same ELF (`b5ac608`), imm32/disp32 patching for cache hits, non-fatal
  DataMask store, optional memory buffer for faster lookups (`7a82b07`), configurable max file size (`83d8317`),
  ValidateCode CRC patching, three DiskCacheVersion bumps. Also `6383292` inline PCMPXSTRX (~10x SSE4.2 string
  ops), `c91c6ef` RDRAND/RDSEED software fallback (default off), `82040ba` new AVX ext reporting, `93def42` x87
  RestoreX87State MM rotation fix, DST_RAX flag removal series, `5006e02` InterruptFaultPage range fix. TSO: nothing.
  Unaligned-atomic prctl: unchanged. FEXInterpreter still removed (our `pocknix-decky-run:27` blocker stands).
  **RootFS json unchanged** (Arch 2026-08-11 `82c0c5f15edf59d2`).
- **steamos-manager:** main has **nothing after `8e2883d` 09-16** (two gpu enum commits + `fd665da` game-message
  validation). No sm8750. But the **`arunr/steam-frame` branch is public** (11 commits, last 08-26) — Armada
  consumes it (section 1). Other public branches: `endrift/battery-charge-type`, `endrift/bus-lockdown`,
  `oSoMoN/robust-device-match`, `work/sitter/sessionmgmt`, `v26.2`, `rel/3.7`. Tags v26.4.1/26.4.0/26.3.0.
- **gitlab.steamos.cloud:** holo group unchanged (dirlock, steamos-manager 09-18; holo-core, gamescope-session,
  jupiter-hw-support, linux-integration still 404). **New public group `frame-public`**: `frame-developer-tools`
  (perfetto/gpuvis/gfxreconstruct wrappers, `pacman/deckard-pacman-src`; README says internal path is
  `deckard/frame-developer-tools`), **`lepton`** (09-11, public 09-17: Valve's rootless Waydroid/Anbox/Halium-based
  Android container "for use with the Steam client ... Most users should use Lepton provided by the Steam Client
  itself"; mounts host mesa/zink, Steamworks libs, Vulkan layers; compat_tool + image; GPL-3 image / MIT tool),
  `android-vulkan-headers`, and Lepton forks of `android_hardware_waydroid` / `android_device_waydroid_waydroid`
  (09-23). *Why it matters:* Valve is shipping an Android-games compat tool for aarch64 SteamOS; on an Odin 3
  (which has real Android on the other slot) it is a future "run Android games under Holodor" path, and it is
  arriving as a Steam compat tool rather than an OS package.
- **Steam client notes 09-17..09-23** (ISteamNews 1675200/4165890/593110): beta 09-21 "**Fixed regression with
  rumble on 3rd party SteamOS Handhelds**"; beta 09-22 "on-screen keyboard not popping up in non-Steam games after
  toggling wifi or suspending"; 09-16 native-Linux crash regression fix. **Frame client 09-22** (Alyx redemption,
  VR QAM click). SteamOS 3.8.28 Beta 09-23 (AMD dGPU post-resume perf). **No ARM64/FEX line.**
- **Proton:** still 11.0-2 (08-21). **proton-cachyos:** still 20260703 (07-22), arm64 assets present.

## 4. Nova-Deck/os-build (github.com/Nova-Deck/os-build) — the most relevant peer

- **Who/what:** Philippe Simons (loki666 — ROCKNIX SM8x50 maintainer), 960 commits since 07-06, 9 stars,
  Claude-driven (`.claude/plans`, worklog). Immutable A/B (RAUC, read-only btrfs), boots via ROCKNIX ABL ("does
  not ship one"), SM8650 lead / SM8550 / SM8250; **SM8750 is a placeholder** (novadeck.plan "SM8750 last w/ known
  gaps"; `packages/README.md` mesa "carries SM8750 / Adreno a830 enablement patches"; no Odin 3 device conf).
- **Deckard consumption — full base switch, 09-23:** `7c0f32c` "consume the official archlinux-deckard tree and cut
  the builder from it" (same snapshot mash-20251118.3, core/extra dbs byte-identical to the preview mirror; builder
  = the snapshot's own `system.rootfs.zst`), then `7d5fb69` **bump to `mash-20260305`** (glibc 2.43, python 3.14,
  systemd 259, qt6 6.10.2, gcc 15.2.1, linux-api-headers 6.19; systemd 259 adds `empower` user which shifted every
  pinned system uid/gid by one — they pin empower=966, rtkit=133; pacman 7.1 needs libmakepkg-dropins+binutils;
  gcc-libs became a metapackage). `a619616` CI watches the deckard tree for new mashes. `docs/base-pin.md` is the
  best public map of the tree: `main/dev/builds/pipeline/tmp` are moving aliases; `mash-YYYYMMDD` is the first
  revision AND the alias that follows `.N`; `.N` frozen; `.pvt`/`-pvt` a second publishing line (`mash-20260305`
  = `.1.pvt`, `mash-20260202` = `.2.pvt`, byte-identical); nothing is signed (`SigLevel = Optional`); each snapshot
  publishes `sources/`; `holo-packages` 302s to `steamdeck-packages`; `archlinux-deckard-hotfixes/<branch>` is the
  Frame-specific layer they do NOT consume; PKGBUILDs live in private `potato/mash/monorepo` and
  `deckard/deckardos/holo`. *Why it matters:* this is the recipe for moving `HOLO_MIRROR` off the frozen preview
  (`mash-20251118.3`, unchanged since 06-10) to a live snapshot, with the uid/gid and pacman-7.1 traps already
  documented.
- **`-deckard` Steam flag trap** (`novadeck-steam:188-200`, measured 08-19): `-deckard` sets ON_FRAME in the client
  UI; the guided-tour "PRESS any button" screen then has no listener (`ON_FRAME ? void 0 : e.onAction`) — a fresh
  card cannot get past first boot. Use `-steamdeck -steamos3 -gamepadui`, never `-deckard`, never `-steampal`.
  `STEAM_SEED.pin`: the gated `-deckard` arm64 client line is newer (1787104891) but refused for the same reason.
- **Kernel 7.2.7** (`6427a8c` 09-22, HW-validated on ACE/Thor Lite/Pocket FIT; "zero drm/msm, zero qcom, zero
  ath12k" in 7.2.7). 7.2.6 "kills Wi-Fi on every WCN7850 board" until their 0535/1060 = Armada 0514 (same Mani
  patch). Stack applies at `--fuzz=0` by policy (`73665ad`), renumbered by subsystem (`7fc92b2`).
- **K13 bug found:** `b5d61c0` 09-23 "0020 oopses when Load128's store-back hits a read-only page" — bylaws'
  emulation reads 128 bits with ldaxp/stlxp but only the ldaxp had an exception-table entry; a CoW/dirty-tracking/
  zram-returned page makes the stlxp fault with no fixup: `Unable to handle kernel access to user memory ... pc :
  Load128+0x38 lr : DoCAS64+0xb8`, game thread dies. Hit on Thor Lite (no LSE2, so every unaligned atomic traps);
  "the bug is on every board". Fix = label the stlxp + exception entry like StoreCAS128 (+1 line). **Armada's 0505
  does not have it.** `0242f01` also confirms FEX-2609 issues the prctl unconditionally (matches our 2607).
- **drm/msm context/VM hardening** `ad67cac` 09-22: Rob Clark's 18-patch series (merged for 7.3) folded as one
  patch incl. `a6d87a272b2c` NULL-deref fix for `_NO_SHARE` GEM_NEW before the ctx VM exists and `df68029e639b`
  resv-swap race. `01a8004` dropped a pending-flush teardown backport that "regresses upstream". `bec938d`/
  `d3eecb0`: eco/balanced -> conservative/ondemand built `=y` (same conclusion as Armada `dce70c1`); `ae1e8cf`
  drops the realtime toggle (same as Armada `918ab54`).
- **SM8550 port (MaSieS4Fun/SteamOS-ARM-SM8550)**, 09-23, 52 stars: Valve Frame userspace "reconstructed at build
  time, not stored in git", ROCKNIX ABL boot, Odin 2 tested; ships lsfg-vk Decky + Box64; internal install as
  `ROCKNIX`+`STORAGE`+`HOME`. No SM8750. (Other agent covers depth.)

## 5. SM8750 / Odin 3 elsewhere

- **Mainline:** no sm8750/a830 patch traffic found since 09-20. 09-23 Qualcomm posted **Adreno 850/845 ("Hawi"/
  "Maili", ADRENO_8XX_GEN2, shares slice architecture with A840)** kernel bring-up on lore
  (`20260923-hawi-gpu-v1-0-0c3c79a1a470@oss.qualcomm.com`) — touches a8xx gen2 catalog/GMU (new GDSC on MxG rail);
  a830 not mentioned; mesa side "forthcoming". Not applicable to 7.1.3; watch for a8xx common-code churn at 7.3.
- **Odin 3 mentions since 09-18:** Armada issues #350/#508/#509/#518 (section 1); ROCKNIX none; pmOS none found;
  Retro Handhelds "Android, Armada and ROCKNIX on my Odin 3" triple-boot piece; windowsforum "Armada needs ABL
  flash". **Holodor:** github.com/transentient/holodor has 0 stars/forks/issues; zero mentions in any other
  GitHub issue/PR (search); no Reddit hits.
- **Nothing new:** Holo Core aarch64 preview (still 06-10); Collabora; ROCKNIX ABL; proton-cachyos; Valve Proton;
  FEX RootFS; steamos-manager main; mesa a8xx fixes; gamescope tags.

## Ranked shortlist (adopt / act)

1. **K13 must carry the Load128 fix** — if/when Armada 0505 is pulled, add Nova-Deck `b5d61c0` (stlxp exception
   entry) on top; Armada shipped nothing yet and their copy is unpatched. `packages/linux-pocknix-sm8750`, effort
   S (one hunk), A/B as planned. Still gated on a board run; Nova-Deck says "NOT HW-validated" for the whole thing.
2. **7.2.x readiness bundle** (not for 7.1.3): ROCKNIX 0606 + Armada `0514`/`0514a` iommu-map cell parsers + `0048a`
   DSI byte-clock rounding; DTS now lives in ROCKNIX `dts/qcom/cq8725s-*.dts*`, not patches — rewrite the sync
   story in `kernel/README.md`/`scripts/sync.sh` before the 7.2 cycle. `packages/linux-pocknix-sm8750`, effort M.
3. **Live Holo Core base** — Nova-Deck's `docs/base-pin.md` recipe: `HOLO_MIRROR` -> `archlinux-deckard/archlinux/
   mash-20260305` (or a frozen `.N`), watch the empower uid shift (966), pacman 7.1 deps, gcc-libs metapackage,
   `SigLevel = Optional` (pin by sha256 in our lock). `config/pocknix.conf`, build-image, effort M-L; do after the
   native-Decky item. Never launch Steam with `-deckard`.
4. **steamos-manager instead of stubs** — holo main `8e2883d` + public `arunr/steam-frame` (0001-0009) + a
   `sm8750.toml` (`ayn,odin3`); Armada's 0011 (InputPlumber target policy) and 0012 (backend write) are the two
   traps, and 0012 is inverted for us (Steam writes `iwd` by default, which is what we run). `packages/
   pocknix-steamos-shim` -> new `packages/steamos-manager`, effort M-L. Gives Steam-native session switching,
   platform profiles, and devfreq GPU clocks.
5. **gamescope 3.16.29 (`8f21264`)** for the rotation experiment — unchanged advice; add `-Denable_zenity=false`,
   re-roll at fuzz 0 (Nova-Deck hit a silent fuzz-2 apply in rendervulkan.hpp). `packages/gamescope` (or
   `gamescope-next`), effort S-M. Don't take Armada's revert as a signal: theirs is the ogc fork with a lease/
   dual-screen stack we don't run.
6. **FEX-2609+ bump** — still blocked on `pocknix-decky-run` `/usr/bin/FEXInterpreter` -> `/usr/bin/FEX`; post-2609
   main adds the Valve DiskCache work (opt-in `FEX_DISKCACHE=1`, thunk-reloc-gated) and inline PCMPXSTRX — wait for
   FEX-2610 rather than a main snapshot. `packages/fex-emu`, `packages/pocknix-decky`, effort S.
7. **Wi-Fi after resume** — Armada/Valve's regdomain-reset-on-resume finding plus ROCKNIX 3171/3173 (still open):
   on iwd, check `iwmon`/journal for a full 6 GHz passive rescan after s2idle before deciding on K3b/K3c.
   `packages/pocknix-bsp-sm8750`, effort S (measure), M (patches).
8. **Tell ROCKNIX / Armada** (HANDOFF NEXT #6): installtointernal still `msftdata` at f15d4a0 lines 174-176;
   Armada #350 (Odin 3 internal install hangs at Starting Steam) is a good thread to mention the EFI-type finding
   in. Effort S.
9. **Mesa pin**: unchanged (main >= `73cd30791b1`); 26.2.4 will not carry the gen8 fixes. `packages/mesa-next`.
10. **Watch, no action:** ROCKNIX 3126 (SM8550 sleep consolidation, USB-off-before-sleep = 2.8 s resume), Armada
    #478 PCIe suspend OPP (KONKR-only), adtbloader (Armada's UEFI path), Valve Lepton (Android games compat tool),
    Adreno 850 a8xx-gen2 kernel churn, Steam beta 09-21 rumble regression fix on "3rd party SteamOS handhelds".

Sources: armada-os/armada commits/PRs/issues (gh api), ROCKNIX/distribution `next` (gh api + clone), ROCKNIX/abl,
ValveSoftware/gamescope master, mesa main + staging/26.2 (gitlab API), FEX-Emu/FEX main + rootfs.fex-emu.gg,
gitlab.steamos.cloud holo/frame-public groups, Nova-Deck/os-build, MaSieS4Fun/SteamOS-ARM-SM8550, ISteamNews
(593110/4165890/1675200), Phoronix Adreno 850 article, armadaos.dev.
