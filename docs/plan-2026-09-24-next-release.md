# Plan for the release after 20260923e (written 2026-09-24, Claude Fable 5.1)

Inputs: Cliff's post-release list (native-Python Decky, boot trims, perf), the four research
reports of 2026-09-24 (links at the bottom), and r/OdinHandheld thread 1wo43p5 "SteamOS for ARM
8gen3 is out!" (docs/reference/reddit-1wo43p5-steamos-arm-2026-09-24.md).

## 0. What actually happened at Valve (the news, decoded)

- **There is no "SteamOS for ARM" download.** Valve turned on public mirrors for the Steam
  Frame OS (codename *deckard*, SM8650 = 8 Gen 3). What is public:
  - `archlinux-deckard/archlinux/{main,mash-*}` = a plain Arch aarch64 rebuild with zero Valve
    packages. It is the **same product as our Holo Core preview, four months newer**
    (`mash-20260305` = `main` today: glibc 2.43, gcc 15.2, python 3.14, systemd 259, pacman 7.1,
    llvm 21.1.8, kwin 6.6). Same layout as our `HOLO_MIRROR`, including `system.rootfs.zst`.
    Unsigned, `SigLevel Optional`, no README/LICENSE, no new terms beyond the preview.
  - `archlinux-deckard-hotfixes/` = the Valve layer: gamescope 3.16.29, steamos-manager 26.4.1
    (DT detection), Valve's private mesa branch (26.3.0_devel abc426bb, a750-tuned), a
    Qualcomm KGSL proprietary Vulkan package they are A/B-ing, kernels 6.16/6.17/6.18/7.2
    **binary only, sm8650 only** (SM8750 pinctrl/interconnect compiled out, no a830 firmware),
    proprietary deckard-hw-support / steam / steamvr tarballs. FEX, Proton, SLR are **Steam
    depots**, not packages. Kernel source is not published anywhere.
  - `steamdeck-images.steamos.cloud/vr/` = rauc + casync delta OTA (0.3.0 public, 0.4.0/0.5.0
    server-side), no full image. The rootfs can be reassembled from the chunk store.
- **Nothing on any Valve mirror touches sm8750 or a830.** Odin 3 is not on Valve's radar.
- **The "port" everyone is linking (MaSieS4Fun/SteamOS-ARM-SM8550)** is Valve's Frame rootfs
  pulled out of the OTA chunk store + an Armbian 7.0.14 SM8550 kernel + ~100 overlay files,
  built by hand on one Ubuntu Odin 2. Not a build system, SM8550 only, `-deckard`-era Frame
  leftovers masked one by one, Steam client hand-seeded from the author's own install, deep
  sleep by fiat, internal installer types the FAT `msftdata` (the AYN Android bootloop we found
  09-17). Its author refuses `qcom,sm8750` explicitly. Reddit reports: Odin 2 Portal boots and
  plays one title, Stardew fails, RP6 has no input (verified cause: input yaml lists only AYN
  models), sleep "coma", no overlay, menu under 60 fps.
- **Peers moved fast (09-18..09-23):**
  - Nova-Deck (loki666, the ROCKNIX SM8x50 maintainer) switched its base to `mash-20260305`
    and documented every trap (`docs/base-pin.md`: systemd 259 `empower` user shifts uids,
    pacman 7.1 deps, gcc-libs metapackage, never pass `-deckard` to Steam). No SM8750 yet.
  - Armada replaced its python shim with the real steamos-manager (holo main + Valve's public
    `arunr/steam-frame` branch) and added `sm8750.toml` with `ayn,odin3`. Also kernel 7.2.6
    with the SM8750 iommu-map fixes, real NM/wpa post-resume patches, K13 merged (unreleased,
    and **missing Nova-Deck's Load128 oops fix**).
  - Valve itself: gamescope 3.16.29 (no newer tag), FEX main is all DiskCache work (no tag
    after 2609), mesa main has **no new gen8 fix**, steamos-manager main quiet since 09-16,
    new public group `frame-public` (Lepton = Android games as a Steam compat tool).

**So what:** the userland we already ship *is* Valve's official aarch64 SteamOS base; the only
thing the release changed for us is that the base is now live and maintained. Holodor's
architecture (Holo base + ROCKNIX kernel + PKGBUILDs) is the right one; the two gaps it exposes
are a stale base pin and the steamos-manager shim. For the Reddit post: Holodor already runs
Valve's Holo Core on Odin 3; "SteamOS for ARM" is Steam Frame firmware, not a distro.

## 1. Release goals (in order)

The next release is a **quality release on the current base**, with the base bump run as a
parallel branch experiment that ships only if it passes the full acceptance list.

1. Decky Loader on native aarch64 Python. (Cliff's #1; also unblocks FEX-2609+.)
2. Resume dead-controls after idle s2idle: instrumented, root-caused, fixed or worked around.
3. Headphone gain staging fixed.
4. Boot: measured on SD and internal, the free trims taken.
5. Perf: the rotation experiment (K11 + gamescope 3.16.29) A/B'd on the device.
6. Parity: internal install + Remove exercised on the RC; ABL kit 1.1.8; Lexar reflashed.
7. Branch experiment: base bump to `mash-20260305` + real steamos-manager. Ships in this
   release only if the full acceptance list passes on it; otherwise it is the headline of the
   one after.

Not in this release: kernel 7.2.x (needs the ROCKNIX DTS-move story, 0514/0514a/0048a, K13 +
Load128 fix; a board-run cycle of its own), mesa pin bump (queued, one variable, separate A/B
session from the rotation experiment), KGSL, Lepton.

## 2. Work packages

Each has Goal / Steps / Files / Test / Effort. Device time is called out because it is the
scarce resource; everything else is fusor-only and can run in parallel.

### WP1 Native Decky (fusor: ~1 day; device: 1-2 h)
Facts: upstream ships only an x86_64 PyInstaller `PluginLoader` (PR #914 for arm64 is open,
unmerged); the backend is portable Python 3.10-3.14; the mash-20251118 mirror already has
python 3.13.7, aiohttp 3.13.2, watchdog 6, packaging 25, setproctitle, jinja, poetry-core,
build/installer. Missing: `python-aiohttp-cors`, `python-aiohttp-jinja2` (pure Python).
1. `packages/python-aiohttp-cors`, `packages/python-aiohttp-jinja2` from PyPI sdists.
2. `packages/decky-loader`: tag v3.2.9, build wheel with poetry-core (`python -m build
   --wheel --no-isolation`), install to site-packages + `/usr/bin/decky-loader`; patch
   `updater.py` so check/do_update are no-ops (the updater downloads the x86 binary into cwd
   regardless of KEEP_SYSTEMD_SERVICE). Frontend built once on fusor with node+pnpm and
   committed as `decky-frontend-v3.2.9.tar.zst` (Pocknix Control dist/ convention); fallback
   is pyinstxtractor on the x86 bundle's static/.
3. `packages/pocknix-decky` -> pkgrel 19: depend on decky-loader, drop fex-emu/fex-rootfs,
   delete PluginLoader.json + x86 seeding; `pocknix-decky-run` -> `exec /usr/bin/decky-loader`
   (no unshare/binfmt/FEXInterpreter); unit ExecStart direct, WorkingDirectory
   /var/lib/decky-loader, drop FEX_APP_CONFIG/network-online; keep the `pidof steam` wait;
   sync script removes stale `~/homebrew/services/PluginLoader` on upgrade.
4. Pocknix Control: `updates.py` can call pacman directly for checks (keep systemd-run for the
   real upgrade); fix the x86-guest comments; `sdcard.py` mkfs direct.
Test: chroot smoke (loader logs "Starting Decky version v3.2.9", :1337 listens, /frontend/
index.js served) -> Lexar: pacman -U, restart, QAM tabs, Decky settings shows v3.2.9 with inert
Update, one store plugin install, 2 reboots. **Take the three numbers on the current x86 build
first** (`systemd-analyze blame`, `systemctl show -p CPUUsageNSec pocknix-decky-loader`,
journal "Starting Decky" -> first inject); nothing measured today, so nothing to quote.
Honest expectation: boot-to-Steam unchanged (loader already waits for Steam at Nice 10); QAM
ready seconds earlier, less CPU in Steam's first minute, no FEX dependency for system UI.
Risk: store plugins with x86 bin/ payloads stop working; watchdog 6/packaging 25 vs caret pins.

### WP2 Resume dead-controls (fusor: hours; device: repro session + 10 idle wakes)
Best upstream match: InputPlumber #732 (open, 09-21, s2idle, Legion Go 2): IP's own hide rules
in /run/udev/rules.d match by volatile node number; on resume the uhid target is recreated
first and inherits a number a stale rule matches -> Steam can't open the virtual controller,
hid-steam falls to lizard mode (d-pad/A navigate, Guide/QAM dead). We ship IP 0.77.2; 0.81.0
carries three resume-related fixes (0.78.1 unhide perms, 0.79.1 suspend composite, 0.80.0
restore perms + re-trigger add).
1. **Ship a read-only forensics hook now** (sleep.d/post in bsp-common): hidraw perms + ACLs,
   /run/udev/rules.d mtimes, IP busctl tree, controller.txt tail -> journal. Next repro has data.
2. ANSWERED 09-25: only Guide/QAM dead, everything else worked = lizard mode. H1 primary, H2/H5
   fallbacks, H3/H4 dropped.
3. Repro on the Lexar with Steam's idle timeout at 2 min; discriminate in this order:
   H1 stale rule/ACL (`chmod 660 + setfacl -m u:deck:rw` on the 28DE hidraw recovers = proven),
   H2 `udevadm trigger --action=add` recovers, H3 `systemctl restart inputplumber` recovers,
   H4 evtest on rsinput dead (MCU), H5 steam.pipe nudge.
4. Fix = #732's udev rule in 60-pocknix-controllers.rules (belt) + IP 0.81.0 (braces;
   re-verify the asymmetric X/Y map in 01-rsinput-controller.yaml).
Acceptance: 10 idle wakes at the UI + 3 mid-game, controls live every time.
Also check (sweep #7): iwd 6 GHz passive rescan after s2idle (Valve/Armada found the radio
returns in a new regdomain on every resume); measure before touching K3b/K3c.

### WP3 Headphone gain staging (device: 1-2 h, UCM edits live)
Root-cause candidate: `HiFi.conf` names `PlaybackMixerElem "HP Digital"`, which does not exist
on this card (copied from Qualcomm's sm8750 MTP UCM) -> PipeWire falls back to software volume:
the 40 % sink is ~-24 dB digital attenuation on a max-analog-gain path (HPHL/HPHR 20 = register
0 = max) = hiss. Base rx-macro also puts the PA in CLS_H_ULP.
Test order: (1) `PlaybackMixerElem "HP"` (already defined in AYN-Odin3.conf) so the slider
drives PA gain at 0 dB digital; (2) if the bogus HPH TLV breaks PipeWire's mapping, BootSequence
HPHL/HPHR 12-14 with software ~90 %, A/B at equal loudness; (3) `RX HPH Mode` CLS_H_LOHIFI /
HIFI / CLS_AB_HIFI, price with telemetry current_now; (4) right-heavy: per-channel wpctl and
WirePlumber stored state first, then speaker-test -s 1 / -s 2 at equal registers, verify RX_RX0
vs RX_RX1 both 84 after jack activation. Ship as bsp-sm8750-19, keep the pkgrel-18 JackControl
block.

### WP4 Boot (fusor: hours; device: one measurement session on SD and internal)
Finding: `KERNEL` is 60 MB because **all 392 DTBs (41 MB) are appended** after gzip(Image),
inherited verbatim from ROCKNIX package.mk; only cq8725s-ayn-odin3.dtb (127 KB) is used, both
in `scripts/build-kernel.sh:361` and on-device `pocknix-build-bootimg:32`. Second finding: on SD
the session is ready at 8.6 s but the splash quits at 10.5 s, so from 8.6 s the critical path is
the 6 s cutscene hold; systemd trims only show on internal storage.
1. B0 first: `systemd-analyze time/blame/critical-chain/plot`, journal short-monotonic, dmesg to
   init, fincore of Steam's tree after first frame, on SD and internal. Nothing recorded today.
2. B1 DTB filter to `cq8725s-*.dtb` in both places (-> ~19 MB KERNEL; KERNEL.bak rollback).
3. B8 remove dead weight: Holo's linux-6.17.8 + mkinitcpio + dracut (87 MB /boot + 126 MB
   modules, never booted, hooks run on every -Syu).
4. B4 stamp-gate pocknix-expand-root (runs Before=getty every boot).
5. B3 getty still After=systemd-user-sessions -> network.target (measure first). B5 nice the
   basic.target daemons. B7 SD-only: read ahead the Steam hot set (libcef/steamui/steamclient)
   at idle priority during the cutscene hold. B6 falls out of WP1.
Not worth it (verified): udev settle, fsck, FEX prewarm.

### WP5 Perf: rotation experiment (device: ~1 h with ssh on the internal install)
Built and staged since 09-20 (`~/odin3-backups/rotexp-20260920`, kernel -27 in the worktree
only): K11 DPU inline rotation + gamescope-next 3.16.29 + POCKNIX_ROTATION=hw. Only lever with
double-digit upside. Protocol and failure signatures in docs/rotation-experiment-2026-09-20.md;
add `-Denable_zenity=false` and re-roll patches at fuzz 0 (rendervulkan.hpp moved). Armada's
3.16.29 revert is their DRM-lease stack, not a signal. Mesa pin bump stays a separate session.
Then in order, each its own A/B: U2 sparse-sync (freeze family), FEX-2609/2610 with DiskCache
(after WP1), scx_lavd vs schedutil (Armada moved to conservative/ondemand for frame-time
consistency: worth one bench), THP/io-sched on internal only.

### WP6 Parity and housekeeping (device: install + Remove run; fusor: minutes each)
Internal install + Remove on the RC; ABL kit 1.1.8 bump (packages/pocknix-bootloader-sm8750 +
INSTALL wording); reflash the Lexar from the published image; PATCHES.md mesa row is stale.
Tell people (drafts in docs/outreach-2026-09-24.md): Armada as a NEW issue (their installer
refuses HOLODOR_ROOT names), MaSieS4Fun on their issue #1 (RP6 has no controller because the
input yaml lists only AYN models). **HELD (09-24 finding):** the "ROCKNIX still types the FAT
msftdata" premise looks wrong: both ROCKNIX installtointernal and MaSieS's installer run
`set N boot on` after `msftdata on`, and on GPT parted's boot flag rewrites the type GUID to EFI
System (reproduced on fusor). Verify with `sgdisk -i` on a real ROCKNIX install before sending
those two; HANDOFF's known-issues line needs the same correction.

### WP7 Branch experiment: live base + real steamos-manager (fusor: 1-2 weeks; device: full acceptance)
Do on a branch, one variable at a time, never in the same A/B as WP5.
1. `HOLO_MIRROR` -> `https://holo-packages.steamos.cloud/archlinux-deckard/archlinux/mash-20260305`
   (pin a mash, never `main`; set HOLO_ROOTFS_SHA256; keep SigLevel Optional since nothing is
   signed). Expect: every PKGBUILD respun for the glibc 2.43/gcc 15.2/python 3.14/llvm 21.1.8/
   libdrm 2.4.131 era; `config/packages/base.list` re-resolved (256 preview names gone, 93 new);
   Nova-Deck traps: systemd 259 `empower` user shifts uids (pin empower=966, rtkit=133), pacman
   7.1 needs libmakepkg-dropins + binutils, gcc-libs is a metapackage; **never `-deckard`**.
   WP1's decky-loader must run on python 3.14 (it does upstream).
2. `packages/steamos-manager` replaces `pocknix-steamos-shim`: holo/steamos-manager main
   (8e2883d, v26.4.1) + Valve's public `arunr/steam-frame` 0001-0009 (Armada's exact recipe) +
   `ayn-odin3.toml` with `dt.compatible = "ayn,odin3"`; carry Armada 0011 (InputPlumber targets
   only when configured); note Armada 0012 (Steam writes `iwd` as Wi-Fi backend; fine for us).
   Session switching moves to steamos-manager: re-test Desktop Mode and the installer GUI.
3. Optional pulls from hotfixes, rebuilt from source: xdg-desktop-portal-holo/gamescope,
   holo-zram-swap, fex-wtf, mangohud 0.8.4, scx-scheds 1.1.3. Do not install hotfix binaries
   (older base inside, libdrm 2.4.134 links, proprietary bits).
Ship gate: cutscene, seedless first boot, jack, Desktop Mode, installer GUI (install, Remove,
Restore stock), RTC, sleep/resume, the WP2 acceptance, and a Cyberpunk bench within noise of
20260923e. If any fail, the release ships on the preview base and WP7 becomes next cycle's
headline.

### WP8 Retroid Pocket 5 (Cliff's addition 09-24; fusor: days; device: Cliff's RP5 at .30)
Recon (docs/rp5-act-two-recon.md, 08-31): the fork already carries a complete sm8250 family
(`kernel/sm8250/`, `devices/sm8250/`: kernel 7.1.2 + 35 ROCKNIX patches, RP5 + Flip 2 DTS,
BSP with runtime board select, UCM, InputPlumber yaml, arm-efi GRUB bootloader package),
hardware-validated by upstream pocknix on ALARM in July, never built on fusor, never run under
Holo Core. Panel is portrait 1080x1920 mounted at 270 (RP6 transpose contract). Boot is the
factory ABL -> GRUB off the SD, no ABL flash, no AVB exposure.
1. Build `DEVICE=sm8250` as-is in a worktree; fix what the Holo-Core-era harness broke for a
   second, arm-efi SoC (pacman.conf, repo, signing, seedless bootstrap paths).
2. Cherry-picks from upstream pocknix per the recon: gpt cmdline `8755514`, DXVK-2 donor
   `d3b4743`/`a8b8635` (required for Proton; adapt to seedless), GPcal `fb6c759`; stay on 7.1.2.
3. SD image, spot-check, then first boot on Cliff's RP5 with him driving (walkthrough rule).
Ship gate: separate image `holodor-rp5-<date>`, its own INSTALL section; not a blocker for
the Odin 3 release.

### WP9 Docked-to-TV experience (Cliff's addition 09-24: "as good as possible")
Was ROADMAP Phase 7 item 3 (with item 4, Bluetooth controllers, as its dependency). Known:
USB host on the hub is proven (ethernet, 09-07); never sleep with the hub attached (USB host
dies on resume); Bluetooth audio pairs, controllers never tried; MaSieS's SM8550 overlay
switches the UCM to a "HiFi (DisplayPort, Speaker)" verb when DP is connected (a working
DP-audio pattern on the sibling SoC); Armada advertises external monitor output in Game Mode.
Unknowns to settle first, in order: (1) does DisplayPort alt mode come up on kernel 7.1.3 on
this DTS (dp controller + usb-c mux nodes in cq8725s-ayn-odin3.dts; dmesg on hub plug);
(2) gamescope output switching (`--prefer-output`, hotplug, refresh/HDR handling on the
external connector; how Armada/ROCKNIX pass it); (3) audio routing to DP (UCM verb, PipeWire
default sink switch on connect); (4) Bluetooth controller pairing + InputPlumber; (5) the
sleep-with-hub crash. Deliverable for this release: a research note plus whatever of 1-3 can
be A/B'd in one device session; the polished experience (auto-switch on dock, right resolution,
sound follows the display, controllers just pair) is the goal, likely over two releases.

## 3. Sequencing

Week 1 (fusor, parallel): WP1 packages; WP2 forensics hook shipped to the Lexar; WP4 B1/B8/B4;
WP6 ABL bump and the three messages; WP7 step 1 started on a branch.
Device session A (~2 h): WP4 B0 numbers on SD and internal; WP1 x86 baseline numbers, then
native decky on the Lexar; WP3 UCM ladder; WP2 repro with the hook in place.
Week 2: WP2 fix + IP 0.81.0; WP1 fallout; WP7 first full respin.
Device session B (~1.5 h): WP5 rotation A/B; WP2 acceptance wakes.
Then: RC respin (recipe in HANDOFF 09-23), internal install + Remove (WP6), publish, and decide
WP7 on its own acceptance run.

## 4. Watch list (no action)

FEX-2610 (DiskCache); mesa main for the four gen8 fixes (26.2.4 will not carry them); ROCKNIX
3126 (SM8550 suspend: USB off before sleep cuts resume 14.6 -> 2.8 s); Armada #478 (SM8750 AOP
sleep-set vote); armada-os/adtbloader (UEFI path); Valve Lepton; Adreno 850 churn at 7.3; Steam
beta 09-21 "rumble on 3rd party SteamOS handhelds" fix; the next non-.pvt deckard mash.

## Sources (internal, export-ignored)
- docs/valve-deckard-survey-2026-09-24.md (repos, versions, images, licensing)
- docs/masies-sm8550-port-2026-09-24.md (the SM8550 port, file by file)
- docs/upstream-sweep-2026-09-24.md (Armada, ROCKNIX, Valve, Nova-Deck delta since 09-20)
- docs/post-release-agenda-2026-09-24.md (WP1-WP5 in full, with file:line refs)
- docs/reference/reddit-1wo43p5-steamos-arm-2026-09-24.md (the thread)
