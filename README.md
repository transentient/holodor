# Holodor

**A SteamOS Linux distro for Snapdragon handhelds.**

[![Odin 3 release](https://img.shields.io/github/v/release/transentient/holodor?filter=!release-rp5-*&label=Odin%203)](https://github.com/transentient/holodor/releases)
<!-- RP5 badge, add with the first RP5 release:
[![RP5 release](https://img.shields.io/github/v/release/transentient/holodor?filter=release-rp5-*&label=Retroid%20Pocket%205)](https://github.com/transentient/holodor/releases?q=rp5)
-->

## Download

Pick your device at **[holodor.bonesaw.com](https://holodor.bonesaw.com)**. Each one has its own image and install guide:

| Device | Install guide | What runs well |
|---|---|---|
| AYN Odin 3 | [INSTALL-odin3.md](INSTALL-odin3.md) | [games tested](docs/games-odin3.md) |
| Retroid Pocket 5 | [INSTALL-rp5.md](INSTALL-rp5.md) | [games tested](docs/games-rp5.md) |

Holodor takes Valve's Holo Core (the official ARM64 SteamOS userland) and mashes it up with the ROCKNIX mainline kernel so it actually runs on Qualcomm chips. It boots straight into Steam Big Picture, leaving your Android partition intact. The build system is set up to add more Snapdragon devices later.

*The name: Holo Core + Odin + that one big guy who held the door.*

**The first hour is going to be janky.** Holodor doesn't pack the Steam client in the image. On the very first boot, it downloads Steam, and as soon as you log in, Steam immediately updates itself again. While that's happening, menus will lag, button inputs will feel ignored, and your storage will grind (especially if you're running off an SD card). Don't panic. It only does this once.

## Isn't ArmadaOS like, **THE** SteamOS for Odin 3 and other android handhelds?

Yeah, [ArmadaOS](https://armadaos.dev/) is great. They have a solid team, support a bunch of devices, and have been shipping for months. If you want the most stable, mature option, go install Armada.

Holodor exists because I wanted to see how close I could get to the real SteamOS, using Valve's actual Holo Core packages on an Arch Linux base instead of rebuilding on Fedora. Honestly? The end user experience isn't massively different. Holodor isn't magically faster. Both use the ROCKNIX kernel and a similar graphics stack. When one project fixes a bug, the other usually ports it over. Open source at work.

We might have better sleep battery drain than ArmadaOS right now. We did a couple weeks ago, anyway. Things move fast. I had to bash my head against the wall to fix Android dual-booting and a full factory restore, so we have those sorted out now. You can read the full breakdown in [docs/armada-comparison-2026-09-13.md](docs/armada-comparison-2026-09-13.md).

## About the use of generative AI coding tools

I made extensive use of Claude and Gemini to get this project done. There are a lot of people with very ill opinions of LLM tools and if that's you, I completely get it, go in peace. 

I apologize for subjecting you to a manifesto, but there are three points I would like to make:

- Nobody asked for AI, but it's here to stay. Very much so in software development and systems configuration. It's good at this stuff. Moreover, it has terrifying capabilities in terms of cybersecurity and there will always, forevermore, be an arms race between white and black hat actors to keep systems and networks safe. 
- People should not use AI as a replacement for creativity or thought. I tend to think that people will develop an aversion to slop when it intrudes in areas of life where they want to experience connection with other humans such as music, literature, art, journalism, etc. We're all already tired of seeing the sloptoks and AI clickbait on youtube. But people should stop doing this.
- Nobody asked for AI. I think it was probably inevitable (e.g. decades of people clicking I Accept on unread EULAs that signed the rights of their data away) and it is simply not going away. Here's a terrifying truth: it's a wealth reactor that doesn't need paying subscribers to keep running. Voting with your dollars is pointless. If you want change, get active. Vote. Choose candidates who are willing to reign in the industry and it's economic and ecological impacts. Getting organized and getting active is vastly more effective than trying to vote with your dollars. 

I have extensively dogfooded and iterated through Holodor with my own devices. I have gone over and re-written most of this documentation, though the code is festooned with comments in Claudish. I hired a human artist to do the pixel art, the very reliable and talented SSalmon. I sincerely hope this is okay with you.

## About the pixel art

I thought it would be neat to have some boot image and a little animation for Holodor. I didn't really want it to be AI slop, though, and interesting true story, Claude discouraged me from asking it to generate the art ("I could do it for you, but that would just be slop. Art is something humans are optimized for, so if your skills aren't up to it, you should commission an artist to do the work for you.")

I found s.salmon on /r/pixelart. It was a great experience working with them! They were extremely professional and prompt, and did excellent work! https://ssalmon-px.carrd.co/

## What Works

| Feature | Status |
|---|---|
| Steam Big Picture (Valve's native ARM64 client) | ✅ Boots directly |
| x86/x86-64 Windows games (FEX + Proton + DXVK) | ✅ Supported |
| Controls (buttons, sticks, paddles, deadzones) | ✅ Configured out of the box |
| Rumble / haptics | ✅ Functional in-game |
| Thumbstick RGB (Odin 3) | ✅ Functional |
| Audio: speakers and headphone jack | ✅ Supported, levels measured |
| Wi-Fi (with post-sleep self-healing) | ✅ Supported |
| Suspend/resume | ✅ Works reliably, even in-game; standby drain under 0.5%/hr |
| Screen refresh (RP5): 60 Hz by default, 120 Hz per game | ✅ Follows the frame limit |
| Power profiles, fan curves, per-game tweaks | ✅ Pocknix Control in Quick Access |
| On-screen keyboard in Desktop Mode | ✅ Icon on the panel |
| Updates | ✅ Through Steam's Settings, or `pacman -Syu` |
| Battery charge limit setting | Experimental - might still charge to 100% |
| Optional install to internal storage | ✅ Supported (keeps Android, but factory resets it once) |

## Current Limitations

- Heavy 3D games are slow. Odin 3: AAA titles around **20-30 fps**; indie and 2D games run flawlessly. Retroid Pocket 5: 2D and light 3D run well, heavy 3D runs at 10-30 fps and the device gets hot. The games pages above have numbers per title.
- DirectX 12 games do not run on the Retroid Pocket 5 (its GPU driver lacks features they need). On the Odin 3, Unreal Engine 5 games need `-dx11` in their launch options and are not yet at a playable frame rate.
- Native Linux games cannot run: Valve's ARM64 Steam client has no Linux x86 runtime, so every game goes through Proton (this works fine; it just means the Windows build is what you get).
- Holodor runs Valve's ARM64 Steam client, which Valve builds for its own hardware (the Steam Frame) and does not support anywhere else. Bugs in the client itself, as opposed to in Holodor, may stay unfixed; Valve closes ARM reports on its tracker as unsupported.
- Kernel-level anti-cheat (EAC, BattlEye) doesn't work. This is an ARM-wide problem that Valve is still figuring out.
- The Steam overlay glitches out in some heavier games. There's a workaround included; working on a real fix.
- Decky Loader may offer you its own update. Decline it. Decky updates arrive through Pocknix Control's Updater with everything else.
- Steam needs free space to install games; keep a few GB spare on the drive or installs can stall the device.

## Installation

Read the guide for your device: **[AYN Odin 3](INSTALL-odin3.md)** or **[Retroid Pocket 5](INSTALL-rp5.md)**.

**TL;DR:** Write the image to an SD card. From Android, run the two scripts on the card: one backs up your stock bootloader (keep that backup!), the other installs the ROCKNIX boot menu. Boot from the SD card to try Holodor. If you like it, the Holodor Installer app copies it to internal storage alongside Android. The guide also covers going back to stock.

## Building from Source

The repo is the build system (forked from `pocknix-os`). Run `make kernel`, `make packages`, `make build`, and `make sd-image`. The scripts in `scripts/` are documented at the top and will yell at you if you're missing dependencies.

**Why the weird requirement below:** Holodor is an ARM64 OS, but you're probably building it on an x86 PC. It uses `qemu-user` registered via `binfmt_misc` to run ARM binaries during the build (same way Docker runs arm64 containers). You need the `C` flag enabled because the build switches users (running `pacman` as root and `makepkg` as a standard user).

**Prerequisites:**
* A Linux machine. Arch users: `pacman -S qemu-user-static qemu-user-static-binfmt` (this sets the `C` flag automatically). Ubuntu/Debian users: `apt install qemu-user-static binfmt-support`, then verify `/proc/sys/fs/binfmt_misc/qemu-aarch64` shows a `C` flag.
* Root access (the scripts mount loop devices and chroot).
* ~50 GB of free space and a lot of patience. The initial package build takes hours.

*(A Dockerfile to make this a one-click build is on the roadmap; not started.)*

## Credits

This project stands on the shoulders of giants. Thanks to:

- **[ROCKNIX](https://github.com/ROCKNIX)**: The SM8750 and SM8250 kernel bring-up, device trees, bootloader, and the gamescope rotation patches.
- **[Valve](https://store.steampowered.com) & [Collabora](https://www.collabora.com)**: For Holo Core itself.
- **[ArmadaOS](https://github.com/armada-os)**: The original Odin SteamOS pioneers. We use their haptics work, suspend fixes, and fan curve editor.
- **[batocera.pocket](https://github.com/darkplace/batocera.pocket)** (lukemotion/suckbluefrog): The stick-LED driver and Wi-Fi fixes.
- **[shuuri-labs/pocknix-os](https://github.com/shuuri-labs/pocknix-os)**: The build harness this repo is forked from.
- **Teguh Sobirin**: Odin 3 and Retroid Pocket audio UCM.
- The devs behind **FEX-Emu**, **Mesa/Turnip**, and **InputPlumber**.
- **[CachyOS](https://github.com/CachyOS)**: The ARM64 Proton build Holodor ships.
- The AYN Odin 3 Linux Discord community for testing and bug reports.
- AYN and Retroid for building solid handhelds with great ARM chips, even if we are squishing their firmware into a tiny partition.

## License

GPL-2.0 (see [LICENSE](LICENSE)). Same as the upstream projects. Boot art by **ssalmon** (CC-BY 4.0).

*Disclaimer: Not affiliated with Valve or AYN. Steam is Valve's trademark. Installing to internal storage will factory-reset your Android partition. Flash at your own risk.*
