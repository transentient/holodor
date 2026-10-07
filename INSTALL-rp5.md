# Installing Holodor on the Retroid Pocket 5

> **This guide is for the Retroid Pocket 5 only.** The steps, the image and the bootloader files are specific to this device. AYN Odin 3 owners: use the [Odin 3 guide](INSTALL-odin3.md) instead.

> DRAFT. Steps marked **[VERIFY]** were written from the Odin 3 guide and the RP5 bring-up notes and have not been walked through on a stock RP5 yet.

You have two options for running Holodor:
* **From the SD card:** Perfect for trying it out. Your Android setup remains completely untouched.
* **On internal storage, alongside Android:** This is much faster. Android will still be bootable from the menu, but please note that the installation process will factory reset Android once.

Both methods require the one-time boot menu setup found in Part II. To get started, complete Part I, then Part II, and finally Part III. Part IV is completely optional. If you are already running ArmadaOS or ROCKNIX, just do Part I and then skip straight to the "Coming from ArmadaOS or ROCKNIX" section.

A quick heads-up about your first boot: Holodor will download Steam and let it update in the background. While this is happening (usually about 30 to 45 minutes), the menus will lag and your storage will work hard. This only happens once! Note that this is a little different from the ArmadaOS experience, as they ship with a client pre-installed.

---

## What you need

* A **Retroid Pocket 5** (either screen revision: the original panel or the Visionox panel).
* A **microSD card** (32 GB or larger). The bootloader is picky about cards; Part II, step 8 checks yours.
* A PC with an SD card reader.
* The Retroid Pocket 5 image: `holodor-rp5-<build>-seedless.img.zst` (3.2 GB) and its checksum file, from [holodor.bonesaw.com](https://holodor.bonesaw.com). The file name contains `rp5`; a file named `odin3` is for a different device and will not boot on the RP5.

---

## Part I - Write the Retroid Pocket 5 SD card

1. Download the RP5 image and its checksum file into the same folder on your PC.
2. Verify the download:
    * **Linux or Mac:** `sha256sum -c holodor-rp5-<build>-seedless.img.zst.sha256`
    * **Windows:** `certutil -hashfile holodor-rp5-<build>-seedless.img.zst SHA256` and compare the output to the checksum file.
3. Write the image to your SD card.
    * **Linux or Mac:** `zstd -d holodor-rp5-*.img.zst`, then `sudo dd if=holodor-rp5-*.img of=/dev/sdX bs=4M conv=fsync status=progress`. Triple-check `/dev/sdX`; this erases the target disk.
    * **Windows:** Decompress with 7-Zip 24.01 or newer (or PeaZip), then write the `.img` with Rufus or balenaEtcher. USBImager writes the `.img.zst` directly.
    * If your tool offers to verify the write, let it.
4. Your PC will now show a small partition on the card containing a folder named `rocknix_abl`. Leave it there; Part II uses it.

---

## Part II - Set up the Retroid Pocket 5 boot menu (one time, from stock Android)

This flashes the ROCKNIX bootloader for the RP5 (the SM8250 build; it refuses to run on any other chip). It replaces two tiny bootloader partitions, backed up first. Android is not wiped or modified.

1. Remove your Google account: **Settings** > **Passwords, passkeys & accounts** > your account > **Remove account**. Remove your screen lock: **Settings** > **Security** > **Screen lock** > **None**.
    * If these stay on, Android locks you out after the factory reset in Part IV. Add them back once Holodor is installed.
2. If Android offers a system update, decline it.
3. Insert the prepared SD card into the RP5 while Android is running. If asked how to use the card, choose portable storage.
4. Open the Android **Files** app, go to the SD card, and copy the whole `rocknix_abl` folder to the top level of **Internal storage**.
5. Back up your bootloader: **Settings** > **Handheld Settings** > **Advanced** > **Run script as Root** > `Internal storage/rocknix_abl/backup_abl.sh`. **[VERIFY the menu path]**
    * The script runner reports success even when it failed. Check: the `rocknix_abl` folder on the SD card must now contain `abl_a.img` and `abl_b.img` (about 1 MB each).
    * Copy those two files to your PC. There is nowhere to download a stock RP5 bootloader.
6. Flash the new bootloader: **Run script as Root** > `flash_abl.sh`. The script checks that it is running on an SM8250 device and stops with a message if it is not.
7. Power off the RP5 (hold Power, choose Power off, wait ten seconds). Hold **Volume Down** and press **Power**. **[VERIFY the key combination on the RP5]** A text boot menu appears. If Android boots instead, repeat step 6.
8. In the boot menu, open **System Stats**. If it lists your SD card, the card works. If it says no card is inserted, repeat Part I with a different card.
9. In the boot menu, find the **device model** setting and pick the entry that matches your screen: **Retroid Pocket 5** or **Retroid Pocket 5 Visionox**. **[VERIFY the entry names]** If the screen stays black after the boot logo in Part III, you picked the other one; come back and switch.
10. Turn off Android updates. **[VERIFY: the RP5 kit does not ship an update-disable script yet; describe Retroid's own setting, or drop this step]**

*To boot Android later: open the boot menu, set the boot mode to Android, and start.*

---

## Part III - First boot of the Retroid Pocket 5 from the SD card

1. Hold **Volume Down** and press **Power**. In the boot menu, set the boot mode to **Linux** and the boot source to **SD card**. **[VERIFY]**
2. After the boot art the screen goes dark for up to two minutes while the file system prepares the card. Wait.
3. The device needs an internet connection to download Steam:
    * **wifi.txt (Recommended):** Put the SD card back in your PC's card reader. You will see one accessible drive (the one with the `rocknix_abl` folder). Create a simple text file named `wifi.txt` there, and type in:
      ```text
      ssid=YourNetworkName
      password=YourWifiPassword
      country=US
      ```
      *(Note: `country` is your two-letter country code, which is required for 5 GHz networks.)* Two things that trip people up: create the file on the card in the card reader, not through the RP5's USB connection (Windows shows a file there that is never actually written to the card); and make sure the name is exactly `wifi.txt`, not `wifi.txt.txt` (Windows hides file extensions by default). Put the card back into the RP5 and boot. Once it connects successfully, the file renames itself to `wifi.txt.imported`. If something goes wrong, you will find a `wifi-import-error.txt` file explaining why.
    * **Wired Connection:** Plug in a USB-C hub with an Ethernet cable attached. Leave it plugged in until Steam has started and you have connected to your Wi-Fi via Steam's network settings. It is safe to power the device off with the hub attached, but do not let it go to sleep with the hub attached; the USB port will not wake up properly until you reboot.
4. The download screen shows progress: a few minutes on a fast card, up to an hour on a slow one.
5. Sign in to Steam. Steam updates itself right after; the menus stay laggy for a few minutes.
6. You are in Steam. Controls, sound and rumble work. A short press of the Power button puts the RP5 to sleep.

---

## Part IV - Install to the Retroid Pocket 5 internal storage (optional, but recommended)

1. Boot Holodor from the SD card with Wi-Fi or a wired hub connected.
2. Switch to Desktop Mode: **Steam menu** > **Power** > **Switch to Desktop**.
3. Open the Holodor Installer: **Application menu** (bottom left) > **System** > **Holodor Installer**.
4. Select **Install Holodor to internal storage**. You are asked how much space to leave for Android (32 GB is a sensible minimum).
5. Confirm and wait 20 to 30 minutes. Do not power off.
6. When it finishes, power off completely, remove the SD card, and power on. Holodor boots from internal storage.
7. **[VERIFY: does the RP5's factory reset re-enable updates / remove the rocknix_abl folder, as on the Odin 3?]**

---

## Coming from ArmadaOS or ROCKNIX

Since you already have the custom boot menu installed, you get to skip almost all of Part II.

1. Complete Part I to write the image to your SD card.
2. Copy your stock bootloader backup to the new Holodor card. Grab `abl_a.img` and `abl_b.img` from the `rocknix_abl/SM8250` folder on your old Armada/ROCKNIX card (or from your PC backup) and drop them into the `rocknix_abl` folder on the Holodor card. **[VERIFY the folder name on the RP5 kit]**
3. Complete Part III. In the boot menu, set the boot source to **SD card**, otherwise your old internal Armada or ROCKNIX system will boot instead.
4. To install Holodor to your internal storage in place of Armada/ROCKNIX, proceed to Part IV. The installer detects your old setup and offers a **Replace with Holodor** option. **[VERIFY on the RP5]**

*Side-by-Side:* keep a separate SD card for each system and use the boot menu to pick the card as the boot source.

*Going back to ArmadaOS:* open the boot menu and select **UNINSTALL CFW & EXPAND USERDATA** (removes Holodor and factory resets Android), then install Armada from its SD card as usual. **[VERIFY the menu entry on the RP5 bootloader]**

---

## Part V - Retroid Pocket 5: going back to Android, or to a completely stock device

1. **Boot Android:** open the boot menu and set the boot mode to Android. Holodor stays on the device.
2. **Remove Holodor:** boot from the SD card, open the Holodor Installer in Desktop Mode, and choose **Remove Holodor**.
3. **Restore the stock bootloader:** after step 2, boot from the SD card once more and run `restore_backup_abl.sh` from **Run script as Root** in Android, with your `abl_a.img` and `abl_b.img` back in `rocknix_abl` on the card. **[VERIFY]**

---

## Troubleshooting

* **Black screen after the boot logo:** wrong screen model selected in the boot menu (Part II, step 9).
* **No Wi-Fi networks listed on first boot:** wait a minute and try again; if it persists, boot with a wired hub.
* **Steam says it cannot reach the internet after sleep:** toggle Wi-Fi off and on in the Steam settings.

## Appendices

### A. Starting SSH

1. Switch to Desktop Mode and open Konsole.
2. Set a password for the `deck` user: `passwd` (press Enter at the "current password" prompt).
3. `systemctl enable --now sshd`
4. From your PC: `ssh deck@<the RP5's IP address>`. The address is under Desktop Mode's network settings.
