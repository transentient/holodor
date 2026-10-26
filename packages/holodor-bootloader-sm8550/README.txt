Holodor bootloader folder for SM8550 / QCS8550 devices (Retroid Pocket Nova / RP6, AYN Odin 2 family)
(Holodor ABL based on OpenABL v1.1 — source: https://github.com/transentient/OpenABL)

Full instructions: INSTALL.md in the Holodor release. Short version:

1. In Android, open the Files app and copy this whole rocknix_abl folder from the
   SD card to the top level of the internal storage (/sdcard/rocknix_abl).
2. Settings > Handheld Settings > Advanced > Run script as Root > backup_abl.sh
   (On AYN Odin 2: Settings > Odin settings > Run script as Root > backup_abl.sh)
   Then check that abl_a.img and abl_b.img exist in this folder on internal storage.
3. Run script as Root > flash_abl.sh
4. Power off. Hold Volume Down and power on: the Holodor boot menu appears
   (navigate with D-Pad, Left Stick, or Volume +/-; confirm with A or Power).
   First boot only: select "Set Device Model" -> "Retroid Pocket 6" (for Retroid
   Pocket Nova / RP6 with top stick) or "Retroid Pocket 6 TOP-DPAD" (top D-pad),
   then select "Boot Holodor from SD" (or "Change default boot to Linux").

Switching between Android and Holodor:
- From Android -> Holodor (1-tap app): Install BootHolodor.apk once in Android,
  then tap the "Boot to Holodor" app icon anytime to reboot straight into Holodor!
  (Or run boot_holodor.sh via Run script as Root.)
- From Holodor -> Android: Open the Decky Quick Access Menu (...) > Holodor >
  Power > "Reboot to Android" (or use "Reboot to Android" on the Desktop).

restore_backup_abl.sh puts your saved stock bootloader back (Holodor can also do
this for you from the installer).
Do not edit these scripts. The runner executes them one line at a time.
