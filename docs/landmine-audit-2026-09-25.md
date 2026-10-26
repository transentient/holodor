# Forgotten-landmine audit of Holodor 20260923e (2026-09-25)

Agent audit, read-only, commissioned by Cliff the morning a reddit user hit the ABL model-menu
trap (392-dtb KERNEL, ROCKNIX ABL 1.1.7). That item is excluded here (fixed by kernel-28 / the
20260925 hotfix image); so is the 2026-09-24 WP1-WP8 work-in-progress. Sources read: HANDOFF.md
in full, all project memory, README/INSTALL, ROADMAP, the 09-04/09-24 plans, the 09-11 dual-boot
review, the 09-05 inquisitor review. Every item was checked against the repo (git grep/log,
`git show release-20260923e:`, current files, build logs) before being listed.

## Not done, ranked

### HIGH

1. **`backup_abl.sh`'s copy-to-SD line has never been shown to work on the device; INSTALL.md
   gives no fallback when it doesn't.** HANDOFF 09-11/09-14: "the /mnt/media_rw/* glob line is
   untested on AYN's runner". Part II step 5 is the mandatory path for every stock-Android user.
   The script writes abl_a/abl_b to /sdcard/rocknix_abl/ (Android userdata, which Part IV wipes)
   and then `cp` to `/mnt/media_rw/*/rocknix_abl/`. If the glob does not resolve under AYN's
   root runner, the files exist only in Internal storage and the doc never says to look there.
   No session after 09-11 ran our backup_abl.sh from the Holodor card (09-15 used Armada's kit,
   09-21 skipped Part II, 09-23 ran flash_abl.sh only).

### MEDIUM

2. **`disable_android_updates.sh` (`pm disable com.odin.fota`) never verified from the "Run
   script as Root" runner.** HANDOFF 09-14 open question, never closed. The runner always
   reports success; taking the OTA is the worst failure in the project (slot b unbootable, FRP).
   Mitigation: Part II step 2 says decline update prompts.
3. **README/INSTALL claim in-game rumble works; no session ever confirmed it.** Only the kernel
   FF path (remote pulses, 08-06) was felt. Trail: HANDOFF 08-06, 08-12, 08-21, 08-26; ROADMAP
   "rumble validation still pending". Valve fixed a "rumble on 3rd party SteamOS handhelds"
   regression in the 09-21 Steam beta (we ship steamdeck_stable). README "What Works" has a
   check mark on it; INSTALL Part III step 6 says "rumble are fully functional".
4. **Shipped SD boot kit is still ROCKNIX ABL 1.1.7.** 1.1.8's menu has no device-model step
   (auto "AYN Odin 3", HANDOFF 09-22), so a 1.1.8 kit would make the model-menu trap
   unreachable from the other end. INSTALL Part II step 8 still describes the model setting.
   Bump = packages/pocknix-bootloader-sm8750 pkgver + INSTALL wording + one on-device flash.
5. **UE5 black-screen fix (a830 `has_64b_image_atomics=False`) root-caused 08-22, parked, never
   shipped; the `-dx11` check never run.** Patch sits in packages/mesa-next/patches-staged/
   0002-freedreno-a8xx-disable-64b-image-atomics.patch (README: "untested"); rode only the
   pkgrel-6 build that lost the 09-06 A/B and was reverted (9905f2a). Any UE5/Nanite title
   (Expedition 33) = black screen with audio; README advertises AAA.
6. **"Stay awake for downloads" (default Always) silently blocks the power button; the "note for
   docs" (HANDOFF 09-09) never landed in INSTALL/README.** During the first-hour Steam
   self-update a short power press does nothing visible; only docs/pocknix-control.md says so.

### LOW

7. Release image built with `SD_TIMEZONE=Asia/Tokyo` (respin recipe); every user's clock shows
   JST until changed (steamos-set-timezone works from Steam Settings). Dev default leaking.
8. INSTALL Appendix A (start SSH) requires typing in Konsole; the image has no on-screen
   keyboard (Holo Core has no plasma-mobile; desktop.list comment is stale). Doc never says a
   USB keyboard is needed.
9. SoundWire codec-enumeration race (1 in ~6 boots silent audio on 08-14) never got the
   probe-retry (ROADMAP "fix if it recurs in soak"; the 3-day soak saw zero). Watch item.
10. README line 61 is stale: "The headphone jack works, but it doesn't auto-detect" — kernel-26 +
    bsp-sm8750-18 auto-switch was accepted 09-23. Undersells the release.
11. The 09-23 splash/boot fixes live only in overlay/ + build-sd-image.sh (unpackaged), so the
    morning-of-09-23 downloaders of 20260920b can never get them via OTA. Small population;
    nothing tells them to reflash.
12. Sleep with a USB hub/dock attached still hangs or kills the USB host (HANDOFF 09-07 "NOT
    fixed"); the only mitigation is one sentence in INSTALL Part III step 3 under the wired
    network bullet, not near the dock/TV use case README promises.
13. Steam Input activation race (game launches with dead controls; quit + relaunch fixes; HANDOFF
    08-18 #4) is not in Troubleshooting. Vampire Survivors hits it.
14. Internal installs made from the unlinked RCs 20260913/14/15 carry the old ROCKNIX-named
    msftdata boot FAT (Android bootloop layout). Installer recognises LEGACY_BOOT_NAME for
    detect/uninstall but nothing retypes an existing install's FAT; those users reinstall.

## Verified done (looked like landmines, confirmed fixed in the release)

Wi-Fi boot race port (5438b8e, iwd-wait-wlan0.conf); wifi-heal via systemd-run --collect; iwd
roam crash (DisableRoamingScan + BandModifier5GHz + RoamThreshold keys in build-sd-image.sh);
charger re-cap 80/70 (70-pocknix-charge-full.rules + service); brownout guard (UPower
PercentageAction=5/PowerOff, powerd refuses <5 %); pocknix-power-mode.service enabled, `max`
reverts at boot; slot-successful anti-brick keeper; root= by PARTUUID + fstab by PARTUUID +
installer re-pin; first-boot RTC=1970 clock seed (75cf663) + kernel-26 RTC-in-SDAM, clock test
passed 09-23; image pacman.conf points only at transentient/holodor-releases with the Holodor
key; Steam client channel steamdeck_stable everywhere; systemd-networkd-wait-online masked;
sdcard-mount root-disk guard; FEX Fast preset labelled unstable; Lossless Scaling requirement
stated in INSTALL + Decky toggle; Android boots after internal install (proven 09-17/18, msftdata
root cause, `parted set N esp on`, HOLODOR name); FRP lockout / stock-ABL restore / clear-frp GUI
/ ABL kit on the SD (09-11 review items 1-5, accepted 09-23); no [VERIFY] markers or em dashes
in README/INSTALL; stale "controller may disconnect after suspend" bullet gone; INSTALL sudo
appendix fixed; release spot-checks: root locked, deck empty, sshd off, no wifi profiles, no
Steam tree; diag hooks 48/49 never in an image; pocknix-flathub Restart=on-failure; plymouth/
getty rebuilt 09-23 (see item 11); fex-emu same-pkgrel repackage predates the first OTA publish;
pocknix-decky-sync reseeds only when the bundled version is newer.

## Reader notes

Items 1 and 2 are "no evidence it was done", not "evidence it fails"; both are five-minute
checks from any Odin on stock Android (run backup_abl.sh, look on the SD; run
disable_android_updates.sh, then `pm list packages -d | grep fota`). Item 3 is the one most
likely to generate public bug reports because README puts a check mark on it. Item 4 plus the
kernel-28 trim close the model-menu trap from both ends.
