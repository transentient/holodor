# Holodor and ArmadaOS: an honest comparison (researched 2026-09-13)

Working notes behind the README section. Every Armada fact has a URL; Holodor facts come
from this repo. Counts are point-in-time and will drift. Rows are tagged documented,
claimed, or unproven.

## Comparison table

| Row | ArmadaOS | Holodor |
|---|---|---|
| Base / userland | Fedora bootc image, Bazzite-style layout, KDE desktop (documented) | Valve Holo Core aarch64 preview (the official SteamOS userland) on Arch packaging (documented) |
| Update mechanism | `bootc upgrade` from Steam's update button; Beta and Preview channels; docs say OTA is "still being validated. You may need to reflash if an update fails" (documented) | Signed pacman repo, `pacman -Syu` (documented); OTA on a fresh install not yet exercised (unproven) |
| Devices | Four Snapdragon SoCs; AYN Odin 2 / 2 Mini / 2 Portal / Thor / Odin 3 and Retroid RP5 / Flip 2 / RP6 / Nova tested; RP Mini and Thor Lite untested; AYANEO and KONKR families listed (documented) | AYN Odin 3 only; Retroid Pocket 5 next (documented) |
| Steam delivery | ARM64 Steam bootstrap and CachyOS Proton pre-staged in the image at build time (documented) | Downloaded from Valve at first boot, about 350 MB; the image ships no Valve software (documented) |
| Suspend | s2idle "native sleep" default since 20260907; docs call it work in progress with "still bugs and power draw remains higher-than-ideal"; open Bluetooth drain issue on Odin 2; no published drain figure (documented) | s2idle, 0.40% per hour measured over 17 hours on the Odin 3 (documented); suspend inside a running game (claimed; a dead-controls-after-resume bug is still listed open in the maintainer notes) |
| Install and dual-boot safety | SD card then Armada Installer; "factory-resets Android"; replaces an existing Linux install in place without touching Android; uninstall from the ABL menu; docs say nothing about Google FRP, restoring the stock bootloader, or Android OTA (documented) | SD card then Holodor Installer; FRP check and clear with consent; replaces an existing Linux install (ArmadaOS, ROCKNIX, older Holodor) in place without touching Android (documented, loop-tested 09-14, not yet on the device); stock bootloader restore from Linux, finds the ROCKNIX/Armada backup layout and refuses any ROCKNIX ABL release by version; bootloader backup kept in three places; Android update-disable script; EDL rules written down (documented); Android boots after an internal install and after Replace (proven on the device 2026-09-17, once the boot partition was typed EFI System like Armada's; the basic-data type we inherited from ROCKNIX's layout loops AYN's Android) |
| Graphics stack | Kernel 7.2.3 with ROCKNIX patches, Mesa 26.2.2, FEX 2608, CachyOS Proton 11; lsfg-vk packaged, no user-facing toggle found (documented) | Kernel 7.1.3 with ROCKNIX patches, Mesa 26.3-devel, FEX 2607, CachyOS Proton; lsfg-vk with a Decky toggle (documented); AAA titles 20 to 30 fps (claimed) |
| People | 17 contributors, 3 core; about 1,800 Discord members; 151 open issues; 1.4k stars (documented) | One maintainer working with AI agents; private repo; no Discord or issue tracker yet (documented) |
| Release cadence | 10 releases between 2026-06-07 and 2026-09-07, 4 to 19 days apart; per-commit preview images (documented) | No public release yet; RC 20260911 on an SD card (documented) |
| Extras | Armada Store (emulators and Decky plugins from Game Mode), Distrobox, Waydroid, experimental HDR, dual-screen mode, external monitor in Game Mode, RGB, fan editor, controller emulation type, per-game FEX presets (documented) | Fan curves, Eco/Balanced/Performance, RGB, wifi.txt headless setup, seedless image, charge limit (experimental), sleep telemetry (documented) |

## Where Armada is better

It exists in public: ten dated releases since June, a 1.4k-star repo, seventeen
contributors, an issue tracker, and a Discord of about 1,800 people. It supports around
a dozen tested devices across four Snapdragon generations, not one. Bugs get triaged by
more than one person and a fix can land in the next build. It has features Holodor does
not: an in-Game-Mode store, Distrobox, Waydroid, experimental HDR, dual-screen support,
external monitor output, per-game FEX presets, and a newer kernel and Mesa. Steam and
Proton are pre-staged, so first boot does not depend on a download. If a user wants
something that works today with people to ask, Armada is the safer choice.

## Where Holodor is different or better

The userland is Valve's own Holo Core rather than a Fedora rebuild, so SteamOS behaviour
comes from Valve's packages instead of being re-implemented; whether that matters day to
day is a judgement call, not a measured fact. Updates are ordinary signed pacman
packages, small and inspectable, though both projects call their OTA new. Standby drain
has a number (0.40% per hour on the Odin 3) where Armada's docs say "higher-than-ideal"
and publish none. The install tooling handles two failures Armada's docs do not mention:
the Google FRP lockout after a userdata wipe, and getting back to a stock bootloader
without Android's script runner. Frame insertion has a toggle. The image ships no Valve
binaries. Against that: one device, one maintainer, no public release, no community, and
the "Android still boots after internal install" claim is not yet proven on hardware.

Long term, both build on the ROCKNIX kernel work and share most of the graphics stack,
so they will converge.

## Inconsistency found in our own docs

README says suspend works inside a running game. INSTALL.md's Known limitations still
says suspending mid-game may disconnect the controller, and the maintainer notes list
"dead controls after resume (in-game)" as open. One of these is wrong; decide which
before release.

## Sources (Armada)

- Org and repos: https://github.com/armada-os ; https://api.github.com/repos/armada-os/armada ;
  https://api.github.com/repos/armada-os/armada/contributors
- README: https://github.com/armada-os/armada/blob/main/README.md
- Site: https://armadaos.dev/ ; devices https://armadaos.dev/devices/ayn/ and
  https://armadaos.dev/devices/retroid/ ; SoC list https://github.com/armada-os/armada/blob/main/abl/README
- Install: https://armadaos.dev/getting-started/flashing-to-an-sd-card/ ;
  https://armadaos.dev/getting-started/install-to-internal-storage/ ;
  https://armadaos.dev/getting-started/uninstalling-and-restoring-android/
- Updates: https://armadaos.dev/getting-started/updating/ ;
  https://armadaos.dev/getting-started/preview-images/ ; `armada-update` and `disk.toml` in the armada repo
- Sleep: https://armadaos.dev/using-armada/sleep-shutdown-and-battery/ ;
  https://github.com/armada-os/armada/issues/264
- Known issues: https://armadaos.dev/troubleshooting/known-issues/
- Armada Control: https://armadaos.dev/using-armada/armada-control/
- Releases: https://github.com/armada-os/armada/releases (20260714, 20260817, 20260907 notes)
- Steam delivery: https://github.com/armada-os/armada-packages/tree/main/steam-bootstrap ;
  `build_files/30-install-steam-session.sh` in the armada repo
- Kernel: https://github.com/armada-os/armada-packages/tree/main/kernel
- lsfg-vk: https://github.com/armada-os/armada-packages/tree/main/lsfg-vk
- Community size: Discord invite HdmdSxTD5S with counts (2026-09-13); press:
  https://retrohandhelds.gg/armada-drops-their-latest-update-to-make-steamos-on-arm-even-better/ ;
  https://retrohandhelds.gg/i-have-android-armada-and-rocknix-on-my-odin-3-and-its-become-my-endgame-handheld/
