# Holodor and ArmadaOS: an honest comparison (researched 2026-09-13, updated 2026-10-07)

Working notes behind the README section. Every Armada fact has a URL; Holodor facts come
from this repo (HANDOFF.md, docs/release-notes, README, INSTALL-*.md, docs/games-*.md).
Counts are point-in-time and will drift. Rows are tagged documented, claimed, or unproven.
The 10-07 pass re-fetched every Armada source; where a number could not be re-verified the
row says so instead of keeping the September figure.

## Comparison table

| Row | ArmadaOS | Holodor |
|---|---|---|
| Base / userland | Fedora bootc image, Bazzite-style layout, KDE desktop; armada-packages repo archived 2026-09-18 and folded into `armada/packages` (documented) | Valve Holo Core aarch64 preview (the official SteamOS userland) on Arch packaging (documented) |
| Update mechanism | Updates from Steam's system settings; Beta (recommended) and Preview (follows `main`) channels; the updating page still says OTA is "new and still being validated. You may need to reflash if an update fails"; Chunkah incremental updates since 20260907; 20260926 adds an Armada Tools desktop app and CLI that can "install OS updates, and roll back to the previous version without Steam running" (documented) | Signed pacman repo, from Steam's Settings or `pacman -Syu`; exercised release to release: the 20260927d image's silent headphone jack was fixed by OTA (bsp 23, 2026-09-29) and Cliff's Odin pulled kernel 33 + bsp 27 from the public repo on 2026-10-02 with a valid signature (documented); no rollback mechanism (documented) |
| Devices | Four Snapdragon SoCs (SM8250, SM8550, SM8650, SM8750); the vendor pages list 21 models, 16 tested: AYN Odin 2 / 2 Mini / 2 Portal / Thor / Odin 3 tested, Thor Lite untested; Retroid Pocket 5 / Flip 2 / Pocket 6 / Nova tested, Mini and Mini V2 untested; AYANEO Pocket EVO / S2 / ACE / DS / DMG tested, S 1K and S 2K untested; KONKR Pocket FIT 8 Elite and G3 Gen 3 tested; 20260926 adds "initial" MANGMI Pocket Max and Air Y Pro with audio not working, not yet on the vendor pages (documented) | AYN Odin 3 released; Retroid Pocket 5 image rc4 built 2026-10-06 (kernel 7.1.2-10, Mesa-next 10, gamescope 8, Pocknix Control 21, systemd-oomd), not flashed, not booted, not published; INSTALL-rp5.md is a draft with [VERIFY] steps (documented) |
| Steam delivery | ARM64 Steam client 1788652215 and runtime 3c.0.20260729 pre-staged at build time from `packages/steam-bootstrap/BASE.env`; site says "CachyOS Proton 11"; 20260926 Armada Tools can "repair Steam by restoring the bundled client while preserving games, saves, accounts, and settings" (documented) | Downloaded from Valve at first boot (INSTALL says 30 to 45 minutes of lag); the image ships no Valve software (documented). Both projects run the same Valve ARM64 client, which Valve builds for the Steam Frame and closes ARM reports against as unsupported (steam-for-linux issues 13689, 13604, 13544) (documented for Holodor's README; Armada's docs do not say this) |
| Native Linux games | Not stated in Armada's docs or release notes (unproven) | Cannot run: the ARM client has no Linux x86 runtime, so a Linux depot fails with "Invalid platform" and every x86 game goes through Proton; found on the RP5 with Hollow Knight 2026-10-06 (documented). The same client ships on Armada, so it probably applies there too (unproven) |
| Suspend | s2idle "native sleep" default on all devices since 20260907; the sleep page still says it is "a work-in-progress" with "still bugs and power draw remains higher-than-ideal, though lower than 'fake sleep'"; 20260926 claims "around a 50% reduction in battery drain" on SM8550/SM8650/SM8750; no published drain figure; the Odin 2 Bluetooth-drain issue (#264) is closed (documented; the 50% is their claim with no number) | s2idle, 0.40% per hour measured over 17 hours on the Odin 3 in September, README says under 0.5%/hr (documented); suspend inside a running game now proven: 8 h s2idle with the jack test matrix identical after wake (2026-10-02), Cliff's sleep/wake test on the 20261002 image passed, 80 s rtcwake with Vampire Survivors running on the k34exp kernel, and the RP5 survived a normal suspend mid-game (documented); RP5 Wi-Fi-after-sleep root-caused and fixed in bsp-common 24 (documented, no post-fix sleep test yet because the USB hub was attached) |
| Install and dual-boot safety | SD card then Armada Installer; fresh install "factory-resets Android (you lose Android apps and data, but the Android system itself stays)"; 20260915 reimplemented the internal installer: "Can now replace any Linux CFW installation alongside Android while preserving Android data"; uninstall from the ABL menu; docs say nothing about Google FRP, restoring the stock bootloader, bootloader backups, or Android OTA (documented) | SD card then Holodor Installer; FRP check and clear with consent ("Fix Android setup lock" button, `pocknix-clear-frp`); replaces an existing Linux install (ArmadaOS, ROCKNIX, older Holodor) in place without touching Android (documented, loop-tested 09-14; still not exercised on a device with Armada actually installed: unproven); stock bootloader restore from Linux, finds the ROCKNIX/Armada backup layout and refuses ROCKNIX ABL releases by version, now including ABL 1.2 (documented); bootloader backup kept in three places; Android update-disable script; EDL rules written down, including the `edl e frp` step the factory recipe needs; Android boots after an internal install (proven on the device 2026-09-17: the boot FAT must be typed EFI System) (documented). RP5 bootloader kit refuses to run on any chip but SM8250 (documented); RP5 install steps unwalked (unproven) |
| Graphics stack | Kernel 7.2.6 with ROCKNIX patches, Mesa 26.2.3 stable, FEX 2609, gamescope 3.16.29-ogc2, CachyOS Proton 11, Vulkan real-time priority by default (20260907); Lossless Scaling Decky plugin "pinned to version 0.12.8" in 20260926, so a user-facing frame-generation toggle now exists via that plugin (documented from the release note; not seen in the Armada Control docs, which still list only FEX presets, fan, power profiles, RGB, controller type, calibration) | Kernel 7.1.3-33 (Odin 3) / 7.1.2-10 (RP5) with ROCKNIX patches, Mesa 26.3-devel (main snapshot 2026-08-09; the RP5 build carries our own UBWC bind-clear fix that stopped the whole-SoC DXVK freeze), FEX 2607, proton-cachyos 11.0-20260702, gamescope 3.16.0-rocknix with our refresh-rate policy, Decky Loader 3.2.9 running natively, lsfg-vk with a "Frame Insertion (LSFG)" toggle in Pocknix Control (documented); AAA titles on the Odin 3 20 to 30 fps (claimed); RP5 per-title numbers measured in docs/games-rp5.md: 2D at 60, Dark Souls Remastered 28, Unity DX11 titles 10 to 23 depending on in-game quality, DX12 titles do not run (documented) |
| Refresh rate | Not stated in Armada's docs; not checked on a device (unproven) | RP5 panel runs 60 Hz by default and switches to 120 Hz only for a game that asks for it (gamescope 8 `dynamic_refresh_default_lowest`), with a per-game "120 Hz Screen" toggle; Hades measured 58 fps steady at 60 Hz versus uneven at 120 Hz (documented, RP5 rc4 only; the published Odin 3 image predates this gamescope and should be checked before an sm8750 publish) |
| Per-game tweaks | Armada Control: FEX preset (Default, Fast, Compatible, Custom), global "Follow Steam" compatibility-tool option with per-game overrides (20260915), CPU topology settings (documented) | Pocknix Control per-game: FEX Preset, Audio Buffer, Frame Insertion (LSFG), 120 Hz Screen, Proton Game Fixes (protonfixes off by default because its winetricks verbs hang; Dark Souls Remastered needed it) (documented; the last two are in Control 21 on the RP5 rc4, the published Odin 3 image has Control 20) |
| Memory pressure | Not stated (unproven) | systemd-oomd on the user slice (kill at 50% pressure for 10 s), in RP5 rc4; never provoked (documented, untested) |
| Audio | Not stated beyond "audio is not working" on the new MANGMI devices (unproven) | Headphone jack on both devices measured on a UCA202 line-in rig: Odin 3 stereo balanced within 0.1 dB at every slider step (20261002, our crosstalk-coefficient fix over ROCKNIX's 0073); RP5 jack ducking root-caused to mismatched compander sequences, fixed, 0.01% THD; RP5 speaker warble root-caused to the WSA compander and the slider redesigned with mic measurements (documented; RP5 fixes in rc4, not published; RP5 jack left/right still needs Cliff's ears) |
| On-screen keyboard | Not stated (unproven) | Desktop Mode has KDE's plasma-keyboard with a show/hide button on the panel (20261002b); no word prediction (documented) |
| People | 30 contributors, 3 with over 100 commits (virtudude 676, JPyke3 161, justradical 114); 1,845 stars, 120 forks, 196 open issues; Discord about 2,750 members (invite API, 2026-10-07) (documented) | One maintainer working with AI agents; public repo transentient/holodor since 2026-09-23 with 23 stars, 0 forks, GitHub Issues enabled with 3 open; no Discord (people are pointed at the AYN Discord's odin3-linux channel); about 56 full image downloads in the last 30 days (R2 logs via scripts/r2-downloads.sh, 2026-10-07) (documented) |
| Release cadence | 13 releases between 2026-06-05 and 2026-09-26 (one marked pre-release), 1 to 19 days apart; two since 09-07 (20260915, 20260926); nothing in the 11 days since; per-commit preview images (documented) | Five tagged releases on the public repo between 2026-09-23 and 2026-10-02 (20260923e, 20260925, 20260927d, 20261002, 20261002b; the last three have release notes); the newest is five days old; RP5 release pending rc4 boot test and a walked INSTALL (documented) |
| Extras | Armada Store (emulators, applications, Decky plugins from Game Mode), Armada Tools (device info, SSH, channels, update, rollback), Distrobox, Waydroid with controller hotplug, experimental HDR, dual-screen mode with Plasma Mobile on the second screen, external monitor in Game Mode, DisplayPort audio on the Odin 3, RGB, fan editor, controller emulation type, conservative CPU governor, translations, boot recovery shortcut (hold Select for Desktop Mode) (documented) | Fan curves with a touch editor, Eco/Balanced/Performance, RGB and stick LED effects, "Zero stick centres", stay-awake-for-downloads, wifi.txt headless setup, seedless image, charge limit (experimental), sleep telemetry, Wi-Fi self-heal after sleep, game-affinity service keeping game threads off the little cores (documented); no store, no Waydroid, no Distrobox, no HDR, no external-display support claims (documented) |

## Where Armada is better

It exists in public at scale: thirteen dated releases since June, a 1.8k-star repo, thirty
contributors, an issue tracker with nearly two hundred open issues, and a Discord of about
2,750 people. It supports twenty-one listed devices across four Snapdragon generations,
sixteen of them tested, where Holodor has one released and one in release candidate. Bugs
get triaged by more than one person and a fix can land in the next build. It has features
Holodor does not: an in-Game-Mode store, Armada Tools with OS rollback, Distrobox,
Waydroid, experimental HDR, dual-screen support, external monitor output, DisplayPort
audio, and a newer kernel (7.2.6 vs 7.1.x), FEX (2609 vs 2607) and stable Mesa. Its
installer now claims to replace any Linux CFW while keeping Android data, which closes the
gap on our Replace mode. Steam and Proton are pre-staged, so first boot does not depend on
a download. If a user wants something that works today with people to ask, Armada is
still the safer choice.

## Where Holodor is different or better

The userland is Valve's own Holo Core rather than a Fedora rebuild, so SteamOS behaviour
comes from Valve's packages instead of being re-implemented; whether that matters day to
day is a judgement call, not a measured fact. Updates are ordinary signed pacman
packages, small and inspectable, and the OTA path has now carried real fixes to real
installs. Standby drain has a number (0.40% per hour on the Odin 3) where Armada's docs
still say "higher-than-ideal" and publish none, though their 20260926 claims a 50% cut.
Suspend inside a running game is proven on both devices. The audio work is measured, not
tuned by ear: balanced headphones on the Odin 3, a clean jack and a redesigned speaker
slider on the RP5, each with root causes written down (one of them is a stock
alsa-ucm-conf bug Armada's RP5 probably shares). The RP5 build has our own Turnip fix for
the DXVK whole-SoC freeze. Refresh handling on the RP5 (60 Hz by default, 120 Hz per
game) is measured to pace better than a fixed 120 Hz panel. Per-game tweaks go further
than FEX presets: audio buffer, frame insertion, refresh rate, and Proton game fixes.
Desktop Mode has an on-screen keyboard. The install tooling handles two failures Armada's
docs do not mention: the Google FRP lockout after a userdata wipe, and getting back to a
stock bootloader without Android's script runner. The image ships no Valve binaries, and
the README says plainly what Valve says about the ARM client and that native Linux games
cannot run on it.

Against that: one released device, one maintainer, 23 stars and a few dozen downloads,
no community of its own, an RP5 release that is still a candidate with a draft install
guide, and several of the measured wins (RP5 audio, 120 Hz toggle, oomd, Proton fixes
toggle) are in an unpublished image.

Long term, both build on the ROCKNIX kernel work and share most of the graphics stack,
so they will converge.

## Inconsistencies found in our own docs

- Resolved since 09-13: README said suspend works inside a running game while INSTALL and
  the maintainer notes listed dead controls after resume as open. Sleep/wake with a game
  running has since passed on both devices (10-02) and INSTALL-odin3.md no longer carries
  the warning. The "game froze and all buttons are dead" tip in INSTALL-odin3.md is about
  the Steam overlay under GPU load, not suspend, and matches Armada's own known-issues page.
- New: INSTALL-odin3.md "Going back to ArmadaOS" says Armada's installer "doesn't recognize
  Holodor's custom partitions, so it cannot cleanly replace them". Armada 20260915 claims
  its reimplemented installer "can now replace any Linux CFW installation alongside Android
  while preserving Android data". Neither side has been tried against the other on a
  device; the INSTALL sentence may now be wrong (unproven either way).
- README's "What Works" row says the RP5 refresh follows the frame limit, and the per-game
  "Proton Game Fixes" toggle is described in docs/games-rp5.md as the default; both are in
  RP5 rc4 and not in any published image.

## Sources (Armada)

- Org and repos: https://github.com/armada-os ; https://api.github.com/repos/armada-os/armada
  (stars 1845, forks 120, open issues 196, 2026-10-07) ;
  https://api.github.com/repos/armada-os/armada/contributors?per_page=100 (30 contributors)
- README: https://github.com/armada-os/armada/blob/main/README.md
- Site: https://armadaos.dev/ ; devices https://armadaos.dev/devices/ayn/ ,
  https://armadaos.dev/devices/retroid/ , https://armadaos.dev/devices/ayaneo/ ,
  https://armadaos.dev/devices/konkr/ ; SoC list https://github.com/armada-os/armada/blob/main/abl/README
- Install: https://armadaos.dev/getting-started/flashing-to-an-sd-card/ ;
  https://armadaos.dev/getting-started/install-to-internal-storage/ ;
  https://armadaos.dev/getting-started/uninstalling-and-restoring-android/
- Updates: https://armadaos.dev/getting-started/updating/ ;
  https://armadaos.dev/getting-started/preview-images/
- Sleep: https://armadaos.dev/using-armada/sleep-shutdown-and-battery/ ;
  https://github.com/armada-os/armada/issues/264 (closed)
- Known issues: https://armadaos.dev/troubleshooting/known-issues/
- Armada Control: https://armadaos.dev/using-armada/armada-control/ ; Store:
  https://armadaos.dev/using-armada/armada-store/
- Releases: https://api.github.com/repos/armada-os/armada/releases (13 total) ;
  https://github.com/armada-os/armada/releases/tag/20260926 ;
  https://github.com/armada-os/armada/releases/tag/20260915 ;
  https://github.com/armada-os/armada/releases/tag/20260907
- Steam delivery: https://github.com/armada-os/armada/tree/main/packages/steam-bootstrap ;
  https://raw.githubusercontent.com/armada-os/armada/main/packages/steam-bootstrap/BASE.env
- Packages (kernel, mesa, fex, gamescope): https://github.com/armada-os/armada/tree/main/packages ;
  the old https://github.com/armada-os/armada-packages is archived (2026-09-18)
- Community size: https://discord.com/api/v10/invites/HdmdSxTD5S?with_counts=true
  (approximate_member_count 2746 on 2026-10-07); press:
  https://retrohandhelds.gg/armada-drops-their-latest-update-to-make-steamos-on-arm-even-better/ ;
  https://retrohandhelds.gg/i-have-android-armada-and-rocknix-on-my-odin-3-and-its-become-my-endgame-handheld/
- Not re-verified on 10-07: a Proton version string in Armada's repo (the site says
  "CachyOS Proton 11"; no proton package directory exists under `armada/packages`, so it is
  fetched by the bootstrap and the exact build is not visible); whether Armada's Lossless
  Scaling toggle is in the Store or Armada Control; whether Armada's new installer handles
  Holodor's partition layout.

## Sources (Holodor)

- Public repo: https://github.com/transentient/holodor ; https://api.github.com/repos/transentient/holodor
  (stars 23, open issues 3, 2026-10-07) ; https://api.github.com/repos/transentient/holodor/releases
- Downloads: scripts/r2-downloads.sh (R2 access logs), run 2026-10-07
- Valve on the ARM client: https://github.com/ValveSoftware/steam-for-linux/issues/13689 ,
  https://github.com/ValveSoftware/steam-for-linux/issues/13604 ,
  https://github.com/ValveSoftware/steam-for-linux/issues/13544
- Repo: HANDOFF.md (2026-10-02 to 10-07), docs/release-notes/*.md, README.md,
  INSTALL-odin3.md, INSTALL-rp5.md, docs/games-rp5.md, scripts/devices.sh, packages/*/PKGBUILD

## Refresh checklist (at each Holodor release)

- Armada releases API: count, newest date, and the kernel / Mesa / FEX / gamescope / Proton
  lines in the newest notes; note anything about sleep drain, installers, or new devices.
- Armada vendor pages: model count and tested/untested split; check whether MANGMI got a page.
- Armada sleep page: has the "work-in-progress / higher-than-ideal" wording changed, and is
  there a drain figure yet?
- Armada updating page: is the "still being validated / may need to reflash" warning still there?
- People counts: repo API (stars, forks, open issues), contributors API, Discord invite API.
- Holodor: release tags on the public repo, repo stars and open issues, scripts/r2-downloads.sh
  for 30-day downloads, package versions from packages/*/PKGBUILD (kernel, mesa-next, fex-emu,
  proton-cachyos, gamescope, pocknix-decky).
- Holodor: move anything tagged "in rc4 / not published" to published once the RP5 image
  ships; re-read the "Inconsistencies" section and drop what is fixed.
- Re-read README's Armada paragraph and the Limitations list against this table; they
  should not claim more than the "documented" rows.
