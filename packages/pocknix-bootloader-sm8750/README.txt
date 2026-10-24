Holodor bootloader folder for the AYN Odin 3 (ROCKNIX ABL v1.1.8)

Full instructions: INSTALL.md in the Holodor release. Short version:

1. In Android, open the Files app and copy this whole rocknix_abl folder from the
   SD card to the top level of the internal storage.
2. Settings > Odin settings > Run script as Root > backup_abl.sh
   Then check that abl_a.img and abl_b.img (1 MB each) exist in this folder on
   the SD card and in the copy on internal storage. The runner reports success
   even when it did nothing.
3. Run script as Root > flash_abl.sh
4. Power off. Hold Volume Down and power on: the ROCKNIX boot menu appears.

disable_android_updates.sh turns off AYN's system update app (recommended for
dual boot). enable_android_updates.sh turns it back on.
restore_backup_abl.sh puts your saved stock bootloader back (Holodor can also do
this for you from the installer).

Switching between Android and Holodor:
- From Android -> Holodor (1-tap app): Install BootHolodor.apk once in Android,
  then tap the "Boot to Holodor" app icon anytime to reboot straight into Holodor!
  (Or run boot_holodor.sh via Settings > Odin settings > Run script as Root.)
- From Holodor -> Android: Open the Decky Quick Access Menu (...) > Holodor >
  Power > "Reboot to Android" (or use "Reboot to Android" on the Desktop).

Do not edit these scripts. The runner executes them one line at a time.
