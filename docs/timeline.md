# Holodor: project timeline

Holodor is a SteamOS-style Linux for ARM handhelds, built on Valve's Holo Core. It runs on the AYN Odin 3 and the Retroid Pocket 5. This timeline runs from June to October 21. All dates are 2026.

## Before Holodor (June – July)

- **Jun 17 – Jul 27:** shuuri-labs builds **pocknix-os**, an Arch-based SteamOS-style distro for the Retroid Pocket 6 and 5, the AYN Flip 2 and the Odin 2 (206 commits). Holodor later forks its build system.
- **Jul 17:** Valve releases Holo Core, an official Arch base for ARM64.
- **Jul 22–27:** Cliff starts tinkering with putting SteamOS-like Linux on the Odin 3.
  - Study of Armada, which runs Steam natively on ARM and runs x86 games through FEX and Proton.
  - Cliff finds AYN's full EDL recovery package on their Discord, which makes an internal install safe to attempt.
- **Jul 28: Holodor kickoff.** pocknix-os is forked, the Odin 3 is added, and the base is swapped to Valve's Holo Core.
- **Jul 31:** fusor, the build box, is built. Development moves off Cliff's Windows PC on Aug 2.

## August: getting the Odin 3 working

- **Aug 2:** v0.2 boots straight to Steam on the Odin 3, with the GPU, controls and Wi-Fi working and no manual fixes.
- **Aug 3–4:** Audio works. First install to internal storage.
- **Aug 5:** Cliff's idea for boot art. The search for a pixel artist on r/pixelart begins.
- **Aug 6:** Rumble works.
- **Aug 9:** A long run of sleep bugs is closed, and the stick LEDs light up.
- **Aug 10:** First release candidate. Boot art commissioned from the pixel artist ssalmon.
- **Aug 13–15:** The Android bootloop is chased. Cliff calls it off on Aug 15.
- **Aug 16–17:**
  - The Cyberpunk benchmarking campaign is closed.
  - SourceForge suspends the project for tripping its anti-abuse checks.
  - The image now downloads Steam on first boot instead of carrying it inside the image.
- **Aug 18:** Over-the-air updates go live through Holodor's own package repository.
- **Aug 21:** Cliff's full test install from an SD card passes. ssalmon delivers the art early, and the boot cutscene goes into the image the same day.
- **Aug 29–31:** The cause of the battery drain during sleep is found. s2idle sleep becomes the default, and a long test run starts on internal storage.

## September: getting ready to release

- **Sep 6–9:** An audit pass ships its fixes (kernel 25). Custom fan curves are added, and a "stay awake for downloads" switch.
- **Sep 11:** Stock Android is restored on the Odin 3 over EDL, and Google's lockout after the reset is cleared.
- **Sep 13:** Downloads move to holodor.bonesaw.com. The first image goes up there.
- **Sep 14:** The install supports people coming from Armada and ROCKNIX.
- **Sep 17:** Root cause of the Android bootloop: the type set on the internal boot partition.
- **Sep 17–18:** Every release check passes on the device: both install paths, Replace, Remove, and Desktop Mode.
- **Sep 21:** Cliff rewrites the install guide.
- **Sep 23: First public release (20260923e)**, announced on Reddit and Discord. ssalmon is credited in the README, and the public repository is split from the development one.
- **Sep 25:** Hotfix for the device-model menu cutting off "AYN Odin 3".
- **Sep 28:** Release 20260927d. Work starts on the Retroid Pocket 5, and how it boots is settled.
- **Sep 29:** Root cause of the Odin 3 headphone jack problem.

## October: the Retroid Pocket 5

- **Oct 2:**
  - Holodor's own Mesa fix ends the RP5 freeze in DirectX 11 and 12 games, which used to lock up the whole chip.
  - Odin 3 release 20261002 is out, with an on-screen keyboard in the follow-up (20261002b).
- **Oct 5–6:** On the RP5:
  - Wi-Fi after sleep is fixed.
  - Speaker and headphone warble are measured with a microphone rig and fixed.
  - A 120 Hz option is added.
  - The first RP5 release candidate is built.
- **Oct 8:** 38 Odin 3 games tested.
- **Oct 9–11:** Release blockers found and fixed:
  - the first boot was corrupting the card while it expanded the partition;
  - Linux apps got no sound;
  - a kernel swap was locking out every rebuilt module.
- **Oct 12–15:** Docks:
  - Video works with the plug either way round (4 of 4 combinations pass, Oct 14).
  - Sleep works while docked, dock audio is back, and the dock's network port no longer breaks Wi-Fi.
- **Oct 16:** Sleep drain cut from about 2.7 % to 0.78 % an hour.
- **Oct 18:** The deep-sleep hunt is closed for this release: Android sleeps at 12 mA, Holodor at 39 mA.
- **Oct 19: First RP5 release.** A Gemini agent (Antigravity) takes over day-to-day work:
  - a "Reboot to Android" button and the BootHolodor Android app;
  - Android ROM cards linked automatically;
  - bypass charging and charge limits.
- **Oct 20:**
  - Holodor's own branded bootloader (OpenABL v1.1) is shipped.
  - The Retroid Pocket Nova's Android setup is backed up. The Nova is the likely 8 Gen 2 test device, in place of an RP6.
- **Oct 21:**
  - On the Odin 3, the main clock crystal switches off during sleep for the first time, for 95 % of a 20-second test. Not shipped yet.
  - Brief written for a second art commission from ssalmon.
- **Oct 22–23:**
  - Odin 3 USB-C DisplayPort video and 3.5 mm headphone audio work together while docked.
  - 73 benchmarks run across the Odin 3 and RP5: 3D games now default to 720p Low on first launch, DirectX 12 works out of the box (including *Hades II* on the RP5 and *The Witcher 3* on the Odin 3), and broken launchers and CPU checks are bypassed automatically.

## By the numbers

- 749 commits since the fork (955 counting pocknix-os).
- 14 images published: 13 for the Odin 3, 1 for the RP5.
- Two devices supported in about 12 weeks.

---

*Compiled on Oct 22 from the git history, the project handoff notes, the release notes and the published downloads. The early-August session logs no longer exist, so that month is rebuilt from the handoff notes and Cliff's own messages.*
