# Dual-boot and restore review, 2026-09-11

Written by Claude Fable 5.1 at Cliff's request after the Android checklist closed. Goal: make
the install easy, convenient and bulletproof; make the SD path a "try it out" experience and the
internal install the real, safe dual-boot; make sure nobody who installs Holodor ends up where
this device ended up in August and on 09-11. Sources: HANDOFF.md (line numbers cited), the
installer scripts, INSTALL.md, README.md, the ROCKNIX ABL package and releases, and the device
over adb today.

## 1. What actually went wrong, and whether a user can hit it

### 1a. The August Android bootloop was a partial firmware flash, not the installer

Proven chain (HANDOFF.md 2481-2491, 226-247): on 08-14 the slot A boot chain was re-flashed to
the Dec-2025 build with fastboot while `super` still held the older build the device shipped
with. The Dec-2025 dm-verity signatures then guarded old filesystems, first-stage init could not
mount /system, and the device looped. Only a complete EDL restore of every LUN fixed it on 09-11.

The installer itself only shrinks `userdata` and appends two partitions. It never writes any
Android firmware partition (installer header, plan text line 180). A user who runs only our
tools cannot produce the August failure. They can produce it later by restoring Android
partially (a fastboot flash of some images but not `super`). That belongs in the docs as a rule.

**What was never proven:** that stock Android boots after `pocknix-install-internal` on the
Odin 3. Nobody booted Android between the ABL flash on 07-26 and the bootloop found on 08-13, and
the bootloop was seen before the 08-14 rebuild that the super-skew explanation leans on
(HANDOFF.md 2852-2853, 2895-2897). README claims "Android preserved, factory-reset" with a
check mark. That claim is untested. The walkthrough must prove it before release.

### 1b. The FRP lockout is caused by our normal path

Google Factory Reset Protection lives in the 512 KB `frp` partition (sda8 on this device). It is
populated when the user has a Google account or a screen lock. Any wipe of `userdata` without
going through Android's own Settings reset leaves it populated, and AYN's Dec-2025 setup wizard
never offers the sign-in that is supposed to clear it. Result: a modal "Factory reset this
device" wall with Reset as the only button (HANDOFF.md 146-160). The only escape found was an
EDL erase of `frp`.

Our installer wipes `userdata`. Our uninstaller wipes `userdata`. AYN's EDL recipe wipes
`userdata` and never writes `frp`. So every user who had a Google account on Android and then
installs Holodor internally, removes it, or restores stock, gets a locked Android. This is the
single worst outcome in the whole flow and it is the default outcome for a normal Android user.
Two re-restores on 09-11 were spent on it.

The fix is small. From Holodor the partition is `/dev/disk/by-partlabel/frp`, 512 KiB, and
writing zeros to it is exactly what the EDL erase did. Android booted clean afterwards. The
partition also holds the "OEM unlocking allowed" bit; zeroing it is harmless on an already
unlocked bootloader (the unlock state lives in devinfo).

### 1c. The slot-successful brick is fixed in the image, with one gap

The ROCKNIX ABL boots Linux through Android's A/B slot machinery. A slot whose `boot_<slot>`
partition is never marked successful loses one retry per boot and at zero the ABL refuses both
OSes (HANDOFF.md 2636-2653). `pocknix-slot-successful` in bsp-common marks the active slot
successful on every Holodor boot, so a shipped image cannot re-brick this way. Gap: the ABL is
flashed before the user ever boots Holodor, and stock Android keeps its own counters, so the
window is small but not zero. Recovery is `fastboot set_active <slot>` from a PC. Worth one
troubleshooting line, not more.

### 1d. The AYN OTA breaks a dual-boot device

Taking the OTA on 09-11 left slot b unbootable for reasons never investigated, and cancelling
the snapshot led into the FRP maze (HANDOFF.md 207-214). An OTA payload also normally carries
`abl`, which would overwrite the ROCKNIX ABL on the target slot; that part is expected rather
than observed. Either way a dual-boot user must not take the OTA. Android nags about it. We can
ship a one-line script for AYN's root runner that disables the update app
(`pm disable com.odin.fota`), reversible with `pm enable`. Recommendation: ship it and document
it as a strongly recommended step, not silently force it.

### 1e. The bootloader backup is stored on the partition we wipe

`backup_abl.sh` writes to `/sdcard/rocknix_abl/`, which is inside Android `userdata`. Our own
copies died with the first internal install (HANDOFF.md 2998-2999, 3182-3183). INSTALL.md tells
the user to copy them to a PC, which is a hope, not a guarantee. There is no published stock
Odin 3 ABL, so a lost backup means EDL is the only way back.

### 1f. The install doc sends users to files that do not exist

INSTALL.md A.1 says to download the ROCKNIX ABL release and copy a folder with the scripts. The
release tarballs (v1.1.7 and v1.1.8, checked today) contain only signed ELFs and checksums. The
scripts come from a `rocknix_abl/` folder ROCKNIX places on its own SD boot partition. Our RC
20260910 SD boot partition holds only KERNEL and KERNEL.md5 (loop-mounted and listed today). A
fresh user is stuck at step A.1. The scripts also use `/sdcard/rocknix_abl/` with no `SM8750/`
subfolder, so the doc's paths are wrong too.

### 1g. Smaller doc and script errors

- INSTALL.md A.2 menu path. Observed today: Settings, then "Odin settings" (subtitle
  "Video&Audio Settings, Joystick Calibration, Google Services"), then scroll to the bottom for
  "Run script as Root". "Enter setup wizard" sits three rows above it and restarts the device
  into the wizard.
- INSTALL.md 60-61 calls `restore_backup_abl.sh` a "full undo of everything". It restores only
  the ABL. Holodor's partitions and the shrunk userdata remain until the uninstaller runs.
- INSTALL.md D.2 says to open a terminal. A GUI exists: "Pocknix Installer" in Desktop Mode
  (kdialog front end, pkexec, no password). The doc should point there and the terminal becomes
  the tinkerer path.
- The installer's abort message says "recover with a PC (fastboot erase / re-flash userdata)".
  The stock ABL has no fastboot `erase` (HANDOFF.md 71-72). The correct advice is simply to boot
  the SD and run the installer again, which the message already says first.
- docs/install-to-internal.md is the RP6 document and names `POCKNIX_ROOT`; the Odin 3 uses
  `HOLODOR_ROOT`.
- INSTALL.md Part C does not warn that the dark gap between splash and Steam looks like a dead
  device and that pressing power there suspends it (HANDOFF.md 1458-1490). It caught Cliff; it
  will catch users.
- B1 (HANDOFF.md 947-951): our internal boot partition is GPT-named `ROCKNIX`, so a real ROCKNIX
  SD cannot boot while Holodor is on internal. Not a Holodor-only user problem; note it in
  Known limitations.
- The red "device is corrupt" screen at every boot on an unlocked device restarts itself if
  untouched; a short power tap continues (HANDOFF.md 44-45). Users restoring stock will see it.
- The 32 GB card silently dropped 120 KB during a write and reported success (HANDOFF.md
  266-276). The doc should tell users to verify the write when their tool offers it.

### 1h. ABL version

v1.1.8 (2026-08-25) changes boot order between internal and SD ("make all modes strict and auto
for internal -> sd card"). Everything on this device was validated on v1.1.7. Ship v1.1.7 now,
test v1.1.8 after release.

## 2. Proposed changes

Ordered by how much user pain they remove. A respin is needed for anything under 2a.

### 2a. Image and tools

1. **Ship `rocknix_abl/` on the SD boot partition.** v1.1.7 ELF plus checksum, `backup_abl.sh`,
   `flash_abl.sh`, `restore_backup_abl.sh`, README, and `disable_android_updates.sh`. The user
   flashes the SD first, puts it in the Odin, and Android can read the folder straight off the
   card. One download, no GitHub trip. Add a `pocknix-bootloader-sm8750` style package or a
   build-sd-image step so the RC matches the repo.
2. **Backups go to the SD card, not to internal storage.** Our `backup_abl.sh` variant writes
   `abl_a.img` and `abl_b.img` to the Holodor SD's boot partition as well as `/sdcard`. The
   installer then copies them from the SD into the internal boot FAT and the Holodor root, so
   the backup survives the userdata wipe and lives in three places without the user doing
   anything. Needs one on-device test of the SD's mount path under Android's root shell.
3. **Installer clears FRP.** Before wiping userdata, read `frp`; if it is not all zero, explain
   in one paragraph what it is and clear it with the user's consent (GUI: a checkbox defaulting
   to on; CLI: a prompt, `--yes` clears). Uninstaller does the same. This alone removes the worst
   outcome in the flow.
4. **"Restore stock bootloader" from Holodor.** A tool that writes the saved `abl_a.img` and
   `abl_b.img` back from Linux, after checking each is 1 MiB, starts with an ELF header, and is
   not byte-identical to the ROCKNIX ELF we ship (the only way a backup taken after the flash
   could sneak in). Exposed in the installer GUI as the last step of "Remove, restore Android".
   Going back to stock then never needs the Android script runner, works even when Android is
   locked or broken, and clears FRP on the way.
5. **"Fix Android setup lock" as a standalone GUI action.** Same frp clear, for a user who is
   already staring at the wall. They boot the Holodor SD, press one button, boot Android.
6. Fix the installer's abort text (drop the fastboot erase clause).
7. Keep v1.1.7. Pin it in the package and name it in the doc.

### 2b. Docs

1. Rewrite INSTALL.md Part A around the SD: flash the card first (Part B moves ahead of it),
   test the card in the ABL menu only after the ABL is in, copy the folder from the card, back up,
   verify the two files on the card, flash. Verified menu names. Warn about "Enter setup wizard".
2. Add a Part A.0: **remove your Google account and screen lock before you start**, with the
   reason in two sentences. Even with the software fix this is the cleanest state.
3. Add "Disable Android updates" as a recommended step with the why.
4. Rewrite Part D around the Pocknix Installer GUI; terminal path in the appendix.
5. New section "Going back to Android, or to stock": three levels. Boot Android from the ABL
   menu (nothing changes). Remove Holodor (GUI, gives storage back, clears FRP). Restore the
   stock bootloader (GUI, from your backup). Then the honest last resort: AYN's EDL firmware,
   with the three rules from HANDOFF.md 2621-2630, the frp erase line, and the red-screen tap.
6. Part C: the dark gap warning ("do not press power for the first two minutes").
7. Known limitations: B1, the red screen on unlocked devices, the card-compatibility window.
8. README: change the internal-install row to match what the walkthrough proves, and not
   before.
9. Retire docs/install-to-internal.md or fix its names.

### 2c. What the walkthrough must prove on the device, in order

1. Part A from the SD folder as a fresh user, including the backup landing on the card.
2. SD boot, first boot, Steam.
3. Internal install through the GUI, with the FRP check showing "nothing to clear".
4. **Android boots from the ABL menu after the install.** Never proven. Gate for the README
   claim.
5. Boot order with the SD left in.
6. Add a Google account to Android, then run "Remove, restore Android" and confirm the FRP clear
   works and Android sets up clean. This is the test that matters most for users.
7. Restore the stock bootloader from Holodor and confirm Android boots on the stock ABL.

## 3. Decisions for Cliff

- Clear FRP automatically with consent (recommended), or only warn.
- Ship `disable_android_updates.sh` as a recommended step (recommended), or only document it.
- Restore-stock-bootloader from Holodor (recommended; makes the Android runner optional after
  the first flash), or keep restore Android-side only.
- Reorder INSTALL.md so the SD is flashed before the bootloader step (recommended; it is what
  makes "one download" true).
