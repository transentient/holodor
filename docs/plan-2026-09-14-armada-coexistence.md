# Coexisting with ArmadaOS and ROCKNIX (2026-09-14)

Written by Claude Fable 5.1 after Cliff's observation: "The first people I am going to pitch
Holodor to on release already run Armada", and Reddit users will want to try both. The install
process must be friendly to (a) swapping one SD card install for another, (b) installing Holodor
internally over an existing ArmadaOS internal install, and (c) ideally, Android + Armada + Holodor
on one device. This file records what was found, what was changed, and what still needs the
device. Status tags: verified (read in source or tested), unproven (needs the Odin 3).

## What was found

- **Same bootloader.** ArmadaOS flashes the ROCKNIX ABL, unmodified, from the same kind of
  `rocknix_abl` folder (their `abl/README`: "From ROCKNIX ... GPL-2.0"). An Armada user already has
  the boot menu, has set the device model, and has done one Android factory reset. Verified.
- **Different backup layout.** Their `backup_abl.sh` writes `rocknix_abl/<SOC>/abl_a.img` (e.g.
  `rocknix_abl/SM8750/`), ours writes `rocknix_abl/abl_a.img` and also copies to the SD card.
  Our tools looked only for the flat layout. Verified, fixed.
- **Different ABL version.** Armada ships ROCKNIX ABL **1.1.8** (`abl/release.env`) and carries an
  updater that can flash it from Linux (`armada-abl-update`, auto-update off by default). Our kit
  ships **1.1.7**. 1.1.8's release notes: "boot: make all modes strict and auto for internal -> sd
  card", "menu: allow grub selection from abl", "menu: install devicetree". Holodor has never
  booted under 1.1.8. Unproven.
- **The ABL is closed.** github.com/ROCKNIX/abl holds a README and an update script; the payloads
  are signed ELFs in the releases. How it chooses an internal boot partition cannot be read, only
  tested. Known from our RP6 work: it boots the internal boot FAT "by its existence, not its
  name" (docs/install-to-internal.md). Armada's ESP is named ARMADA (renamed from ROCKNIX by
  `armada-esp-rename`) and boots, which agrees.
- **Armada's internal layout.** After `userdata`: `ARMADA` (FAT16 ESP, /KERNEL Android boot
  image), `ARMADA_BOOT` (ext4, BLS entries), `ARMADA_ROOT` (btrfs). Their installer has two
  operations: fresh (shrink userdata, factory-reset Android) and **replace** (anything after
  userdata is erased and reused; userdata untouched, no reset). Verified in
  `system_files/usr/libexec/armada/armada-installer`.
- **Our installer refused their disk** ("userdata is not the last partition"). The only path was
  the ABL's "UNINSTALL CFW & EXPAND USERDATA" (Android reset) and then our fresh install (Android
  reset again). Verified, fixed.
- **Our stock-bootloader check knew one payload.** `pocknix-restore-stock-abl` refused only a
  backup byte-equal to our 1.1.7 ELF. A backup taken after an Armada 1.1.8 flash would have passed
  as "stock" and been written back. Verified, fixed.

## What changed (this commit)

- `pocknix-install-internal --replace`: Armada's rule, verbatim. Everything after `userdata` is
  erased and Holodor is put in that space; `userdata` is neither resized nor wiped; no frp
  question. `--detect` now reports `tail_kind` (holodor / armada / rocknix / unknown),
  `tail_names`, `tail_gib`, `replace_ok`. Partition numbers are re-read by start offset after
  creation, never assumed. Tested on a loop device with a fake Armada layout (fusor, 09-14): the
  three Armada partitions were removed, `ROCKNIX` + `POCKNIX_ROOT` created and formatted,
  userdata byte-untouched; fresh path unchanged.
- Holodor Installer (GUI): an ArmadaOS / ROCKNIX / other install is now offered "Replace with
  Holodor (Android is not touched)". Reinstalling Holodor over itself uses the same path and no
  longer factory-resets Android. Restore stock bootloader can browse for the backup folder.
- `pocknix-restore-stock-abl`: searches `rocknix_abl/<SOC>/` too, any mounted removable drive
  (`/run/media/*/*/rocknix_abl[/<SOC>]`), and `--from` accepts the parent folder. Identifies any
  ROCKNIX ABL release from `/usr/share/holodor/rocknix-abl-releases.tsv` (Armada's catalog,
  GPL-2.0-or-later; our own payload matches its 1.1.7 SM8750 row) and refuses it by version.
- INSTALL.md: a section for people already on ArmadaOS or ROCKNIX.
- Adversarial review by a second agent (25 tool uses, its own 4K-sector loop rig with a decoy
  partition numbered after userdata but located before it): no data-loss path found. Its four
  findings were fixed the same day: CRLF-proof catalog parsing plus a loud "catalog unreadable"
  signal; the CLI recovery text now prints on every failure after the disk is touched; free
  space after userdata (an interrupted replace) is offered as a replace target instead of a
  fresh install that would reset Android; `--from` accepts a card's root folder.

## Device findings so far (2026-09-15, Cliff driving, the Armada-user path from stock)

- **Armada's kit flashed ROCKNIX ABL 1.1.8** from stock Android via Odin settings > Run script as
  Root (their `rocknix_abl/SM8750/flash_abl.sh`). Their `backup_abl.sh` writes ONLY to Android
  internal storage (`/sdcard/rocknix_abl/SM8750/`), not to the SD card. Backup copied to the PC
  and to fusor (`~/odin3-backups/armada_rocknix_abl-20260915-stock`): both slots identical, valid
  ELF, matches no ROCKNIX release (genuine Dec-2025 factory ABL, differs from the August backup
  because of the 09-11 full factory restore).
- **The 1.1.8 menu** (verbatim): boot mode `linux`/`android`; abl mode `silent`; alt volume up
  `android`; **boot source `auto`** (Armada's docs name the other values `Internal` and
  `SDCard`; `auto` = internal first, then card); offmode charging `on`; version v1.1.8. **No
  "set device model" step**: System Stats already read "model ayn odin 3". System Stats: SoC
  Snapdragon 8 Elite Gen 1, 16 GB, 512 GB, display 1920x1080.
- **Card visibility under 1.1.8:** 128 GB Silicon Power (new, invisible to 1.1.7): STILL "sd card
  not inserted". 64 GB Axe: seen as 64GB. So the SD limitation is not a 1.1.7 artifact; the
  INSTALL.md wording stands.
- Armada 20260907 boots from the Axe card under 1.1.8 ("preparing armada", one self-reboot, then
  the Steam intro + client update). Armada Installer lives in Desktop Mode, KDE launcher >
  System (desktop entry `Categories=System;Settings;`, shown only when booted from a card).
  Its Android-size control is a slider with 1 GB step buttons; Cliff: "this should not be a
  slider" (ours is a size list).
- Rufus + their `.img.gz`: progress jumps to "100% please wait" almost at once (gzip trailer
  stores size mod 4 GiB, likely) and then writes silently for a long time; killing it left a
  card that matched the image only for the first ~7.6 GB. Rewritten from fusor with a full
  read-back; the reader dropped one window (third time), repaired with rewrite-sd-window.sh.

- **Armada internal install (their installer, ~32 GB for Android) then Android set up cleanly**
  (no lock, no account). With the Holodor card inserted and boot source `auto`, **Armada boots**
  (auto = internal first, observed). With boot source **`SDCard`**, **Holodor RC 20260914 boots
  under ABL 1.1.8**: AYN logo, Holodor art, cutscene (cut short by the compositor handoff), the
  text first-boot setup, Steam download over the USB-C hub's ethernet, zombie marquee, Steam.
- **BLOCKER FOUND: "Switch to Desktop" drops to a tty.** `~/pocknix-session.log` on the card:
  `pocknix-desktop: startplasmamobile not found`. Holo Core's repo has no plasma-mobile,
  plasma-nano or kscreen (desktop.list had them commented out "not in Holo Core preview"), so
  Desktop Mode, and with it the Holodor Installer GUI and all of Part IV, never worked on the
  Odin 3. HANDOFF had it logged 08-25 as "diagnose why startplasmamobile fails". Fix (09-15):
  plasma-desktop + plasma-pa from Holo Core (resolve offline), pocknix-desktop-10 starts
  startplasma-wayland (SteamOS's desktop), rotation comes from the DRM panel-orientation hint
  (DT `rotation = <90>`, kwin honours it), scale 2.0 seeded into `~/.config/kwinoutputconfig.json`
  keyed by connectorName DSI-1 because there is no kscreen. Untested until the next RC boots.

## 2026-09-17: ROOT CAUSE FOUND. Internal boot FAT typed "basic data" loops Android. FIXED.

Bisected on the device with Cliff (each cycle: change from the Holodor SD over ssh, boot Android):
1. Restore userdata's Android type GUID: still loops.
2. Delete our internal boot FAT (`--disable-boot`), root left intact: **Android boots.**
3. Recreate it, type EFI System (C12A7328), name+label HOLODOR: **Android boots; Holodor boots
   from it too** (boot source Internal). The only cost: the rebuilt partition has a new PARTUUID and
   the internal fstab waited 90 s for the old one (fixed in `--enable-boot`).
4. Same partition, EFI type, name+label back to ROCKNIX: **Android boots** -> the name is
   irrelevant, the TYPE is the trigger. The Holodor SD card (basic-data FAT, label ROCKNIX) was
   inserted for every one of these boots -> a basic-data FAT on the CARD is harmless; only one on
   the internal UFS trips Android. Mechanism inside Android/ABL unknown (no crash log obtainable:
   no cache partition, recovery.log clean, STRICT_DEVMEM); not needed for the fix.

This is what looped Android in August too (first internal install ever, same installer). ArmadaOS
types its ESP EFI System (and its SD boot partition too) and never hit it. ROCKNIX's own
installtointernal convention (msftdata "ROCKNIX") is what we copied; whether ROCKNIX users on the
Odin 3 with the Dec-2025 Android see this is worth asking them.

Fix (this commit): pocknix-install-internal and pocknix-uninstall-internal --enable-boot run
`parted set N esp on` after creating the boot FAT; defaults renamed to HOLODOR (GPT name + FAT
label; legacy ROCKNIX-named installs still recognised everywhere); the installer finds the SD's
boot FAT by its own label (ROCKNIX) instead of the internal label; --enable-boot repoints
/flash in the internal fstab to the new PARTUUID; pocknix-restore-stock-abl looks for HOLODOR or
ROCKNIX on the internal disk. The SD image layout is unchanged (Windows must keep seeing it).

## 2026-09-17/18: acceptance with RC 20260917 (Cliff driving)

- Armada 20260907's installer ("Switch to Armada") REFUSED our layout: "an unrecognized partition
  lies after userdata on /dev/sda; refusing." Its release installer is a bash script that
  recognises exactly ROCKNIX, STORAGE, ARMADA, ARMADA_BOOT, ARMADA_ROOT (their git main is the
  Python rewrite that replaces anything). Renamed our root to STORAGE from Armada over ssh
  (user armada / password armada, sshd off by default) and their replace ran; Armada internal
  booted; Android booted. INSTALL.md now says: going back to Armada = ABL UNINSTALL CFW until
  Armada ships the new installer. Their UI names the existing install by partition name and
  sums only the partitions it recognises ("Rocknix: 0GB" with HOLODOR_ROOT).
- Holodor RC 20260917 card next to internal Armada, boot source SDCard: first boot, Steam, Desktop
  Mode with the boot-art wallpaper; Holodor Installer: "ArmadaOS", Replace; Holodor boots from
  internal; **Android boots** afterwards. The headline claim holds on the shipped image.
- Cosmetic, logged: the boot cutscene is choppy from a card and is cut off by the compositor
  handoff; Armada's shutdown takes over a minute with the fan at full.

## 2026-09-15/16: Replace worked, Android then bootloops. (Superseded by the sections above.)

Sequence: Armada internal (their installer, Android 32 GB) -> Android set up and booting ->
Holodor 20260915 card (boot source SDCard) -> Desktop Mode works (first time on this device,
scale 2.0 good, brief sideways flash at start) -> Holodor Installer detected "ArmadaOS (403 GB
after Android)", Replace ran, install completed -> boot source SDCard with no card = ABL error
(strict), Internal boots Holodor (into Plasma: the clone carried the session choice; fix
queued) -> **boot mode android: AYN logo / blank / AYN logo, ~12 s period, forever.**

Everything checkable was checked from Linux over ssh (root via `systemd-run` under the wheel
polkit rule; the release image has no sudo and a locked root), all read-only:
- fastboot getvar: slot a active, successful, 5 retries, nothing unbootable; ABL 1.1.8.
- `fastboot boot` of the factory boot.img (RAM only) loops the same way -> the ABL's Android path
  and the boot image are not it; the kernel runs ~12 s and dies.
- 72 static factory images (LUN0 + LUN4: boot/init_boot/vendor_boot/dtbo/vbmeta*/modem/dsp/
  xbl...) byte-identical to the Dec-2025 EDL package; super's 8 chunks identical (dm-verity has
  nothing to trip on); only abl_a/b (ROCKNIX), vm-bootsys_b, logfs, vm-persist, persist differ
  (expected). misc: BCB empty; the bytes at 32 KiB are Android's own virtual-A/B + memtag records.
- userdata: encrypted (metadata encryption; no signature is normal); f2fs structures sit exactly
  at the current start (7518208), so Android formatted it there; a stale factory superblock at
  7517992 lies outside the partition. Type GUID is Linux-fs (0fc63daf) not Android's 1b81e7e6;
  Armada's sfdisk writer preserves types and parted (tested, 3.6/3.7) preserves unknown GUIDs
  and unaligned starts, so who changed it is unknown; Android booted with it after Armada.
- metadata (f2fs) mounts ro: vold/metadata_encryption/key/* present, ota/snapshots empty,
  bootstat reason "shutdown,userrequested". No UFS I/O errors in any Holodor journal; Holodor
  never mounted an Android partition.
- Hiding our internal KERNEL (rename) did not change the loop. devinfo holds only ROCKNIX ABL
  settings (BootSourceMode 3, ModelSelection AYN Odin 3, AltVolumeUp) + avb persistent value.
- Android's fstabs (first stage + vendor) and all of vendor/system/product/odm contain no
  reference to ROCKNIX. rawdump holds no readable text. Holodor's kernel has STRICT_DEVMEM and
  no ramoops node, so Android's crash log cannot be read from Linux.

**Not yet tried (all need Cliff's buttons; commands ready):**
1. Android recovery via the misc BCB ("boot-recovery" at 0 + "recovery\n" at 64, from the SD
   Holodor over ssh), then boot mode android -> recovery -> "View recovery logs" -> last_kmsg
   = the panic. Afterwards zero the first 2 KiB of misc only (leave the 32 KiB records).
2. Delete our internal boot FAT (`pocknix-uninstall-internal --disable-boot` from the SD) and
   boot Android: isolates "our partition's presence breaks Android". Reversible (--enable-boot).
3. Put userdata's type GUID back (`sgdisk -t 17:1b81e7e6-f50d-419b-a739-2aeef8da3335 /dev/sda`)
   and boot Android. Reversible.
4. Last resort: the 09-11 EDL factory recipe (Android only, ~1 h) after copying nothing (no
   user data of value on the device).

Same shape as the August bootloop after the first internal install (HANDOFF: "never proven that
stock Android boots after pocknix-install-internal on the Odin 3"). Armada's install + Android
boot worked in the same session, so the difference is in what OUR install or OUR Linux boot
leaves behind, and it is not in any static partition.

## What still needs the device (Cliff drives; agent reads state on request)

The Odin 3 is on stock Android, so the Armada-user path can be reproduced exactly.

1. Install ArmadaOS the way its docs say (their card flashes ABL 1.1.8; their backup lands in
   `rocknix_abl/SM8750/` on their card and on Android internal storage). Install it to internal
   storage with their installer. Boot it once. This is the starting state of the users we pitch to.
2. Insert the Holodor card. Which boot menu setting boots it with Armada on internal storage?
   Under 1.1.7 internal won; 1.1.8 says "all modes strict". Record the exact menu names. This
   goes into INSTALL.md as fact, replacing the hedged sentence there now.
3. Holodor Installer on that device: it must say "ArmadaOS is installed", offer Replace, and
   finish. Then: remove card, power on, Holodor boots; Volume Down, boot mode Android: Android
   comes up **without** a setup wizard (proof that userdata was untouched).
4. Restore stock bootloader: with the Armada card's `rocknix_abl` folder copied onto the Holodor
   card (both layouts), the GUI must find it; with a backup taken after the Armada flash it must
   refuse and name "v1.1.8 for SM8750".
5. ABL 1.1.8 itself: does the Holodor card boot, install, and boot from internal under 1.1.8?
   If yes, bump `packages/pocknix-bootloader-sm8750` to 1.1.8 (README.provenance says bump only
   after an on-device test) so new Holodor users and Armada users run the same bootloader.
6. Two internal boot partitions (triple boot, see below): with Armada's `ARMADA` FAT and our
   `ROCKNIX` FAT both present and both holding a /KERNEL, which one boots? Does renaming or
   removing the KERNEL file on one hand control to the other? Does "grub selection" in the 1.1.8
   menu let an EFI GRUB on one FAT chain to the other?

## Triple boot: Android + ArmadaOS + Holodor

Not possible with what is known today, and not something a doc can promise before test 6. The
options, in order of preference:

- **ABL menu support.** The right place, but the ABL is closed source and ROCKNIX's; we can only
  ask. Worth an issue on ROCKNIX/abl once test 6 gives facts.
- **One GRUB on the ESP, two entries.** 1.1.8 added "allow grub selection from abl" and
  "install devicetree". If the ABL can chainload `EFI/BOOT/bootaa64.efi`, a GRUB menu with a
  Holodor entry (raw Image + dtb, what our sm8250 profile already does) and an Armada entry
  (its BLS entry on `ARMADA_BOOT`: kernel, initrd, `fdtdir`, ostree kargs) would be standard
  tooling. Armada regenerates its /KERNEL on every update, so the GRUB entry would have to read
  Armada's BLS files, not copy them. Untested end to end.
- **A "boot the other one next" switch.** If the ABL boots the first FAT holding /KERNEL, each
  side can hide its own KERNEL (rename) to hand over. Crude, one-directional unless Armada
  ships the matching switch. Last resort.

Until one of these is proven, the honest offer is: Android + one Linux on internal storage, the
other Linux on an SD card, and Replace to swap which one is internal without touching Android.
