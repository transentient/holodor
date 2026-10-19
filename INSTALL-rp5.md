# Installing Holodor on the Retroid Pocket 5

> **This guide is for the Retroid Pocket 5 only.** The steps, the image and the bootloader files are specific to this device. AYN Odin 3 owners: use the [Odin 3 guide](INSTALL-odin3.md) instead.

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
5. Back up your bootloader: **Settings** > **Handheld Settings** > **Advanced** > **Run script as Root** > `Internal storage/rocknix_abl/backup_abl.sh`.
    * The script runner reports success even when it failed. Check: the `rocknix_abl` folder on the SD card must now contain `abl_a.img` and `abl_b.img` (about 1 MB each).
    * Copy those two files to your PC. There is nowhere to download a stock RP5 bootloader.
6. Flash the new bootloader: **Run script as Root** > `flash_abl.sh`. The script checks that it is running on an SM8250 device and stops with a message if it is not.
7. Power off the RP5 (hold Power, choose Power off, wait ten seconds). Hold **Volume Down** and press **Power**. A text boot menu appears. If Android boots instead, repeat step 6.
8. In the boot menu, open **System Stats**. If it lists your SD card, the card works. If it says no card is inserted, repeat Part I with a different card.
9. In the boot menu, find the **device model** setting and pick the entry that matches your screen: **Retroid Pocket 5** or **Retroid Pocket 5 Visionox**. If the screen stays black after the boot logo in Part III, you picked the other one; come back and switch.

*To boot Android later: open the boot menu, set the boot mode to Android, and start.*

---

## Part III - First boot of the Retroid Pocket 5 from the SD card

1. Hold **Volume Down** and press **Power**. In the boot menu, set the boot mode to **Linux** and the boot source to **SD card**.
2. After the boot logo, the screen goes dark for up to two minutes while Holodor expands the file system on the card. Let it finish.
3. The device needs an internet connection on first boot to download Steam:
    * **wifi.txt (Recommended):** Put the SD card back in your PC's card reader. Open the small visible drive (the one with the `rocknix_abl` folder) and create a plain text file named `wifi.txt` containing:
      ```text
      ssid=YourNetworkName
      password=YourWifiPassword
      country=US
      ```
      *(Note: `country` is your two-letter country code, which is required for 5 GHz networks.)* Two common pitfalls: create the file with the card in your PC's card reader rather than over a USB cable to the RP5, and make sure the file is named `wifi.txt` and not `wifi.txt.txt` (Windows hides file extensions by default). Put the card back into the RP5 and boot. Once it connects, the file renames itself to `wifi.txt.imported`. If something goes wrong, check `wifi-import-error.txt` on the card for the reason.
    * **Wired Connection:** Plug in a USB-C hub or dock with an Ethernet cable attached. Leave it plugged in until Steam starts and you have connected to your Wi-Fi in Steam's network settings.
4. The download screen shows progress. It takes a few minutes on a fast card, or up to an hour on a slow one.
5. Sign in to Steam. Steam updates itself right after, so the menus will feel sluggish for a few minutes while it finishes unpacking in the background.
6. You are in Steam. Controls, sound, headphone jack detection, and rumble all work out of the box. A short press of the Power button puts the RP5 to sleep.

---

## Part IV - Install to the Retroid Pocket 5 internal storage (optional, but recommended)

1. Boot Holodor from the SD card with Wi-Fi or a wired hub connected.
2. Switch to Desktop Mode: **Steam menu** > **Power** > **Switch to Desktop**.
3. Open the Holodor Installer: **Application menu** (bottom left) > **System** > **Holodor Installer**.
4. Select **Install Holodor to internal storage**. You will be asked how much space to leave for Android (32 GB is a good minimum).
5. Confirm and wait 20 to 30 minutes while it copies the system over. Do not power off the device during the install.
6. When it finishes, power off completely, remove the SD card, and turn the RP5 back on. Holodor will boot straight from internal storage.

---

## Coming from ArmadaOS or ROCKNIX

Since you already have the custom boot menu installed, you can skip almost all of Part II.

1. Complete Part I to write the image to your SD card.
2. Copy your stock bootloader backup to the new Holodor card. Grab `abl_a.img` and `abl_b.img` from the `rocknix_abl/SM8250` folder on your old Armada or ROCKNIX card (or from your PC backup) and drop them into the `rocknix_abl` folder on the Holodor card.
3. Complete Part III. Make sure to set the boot source to **SD card** in the boot menu, otherwise your existing internal Armada or ROCKNIX install will boot instead.
4. To install Holodor to internal storage in place of Armada or ROCKNIX, follow Part IV. The installer will detect your existing Linux partitions and offer a **Replace with Holodor** option that leaves Android alone.

*Running both from SD cards:* keep a separate SD card for each distro and set the boot source to **SD card** in the boot menu.

*Going back to ArmadaOS:* open the boot menu and select **UNINSTALL CFW & EXPAND USERDATA** (this removes Holodor and factory resets Android), then install Armada from its SD card as usual.

---

## Part V - Retroid Pocket 5: going back to Android, or to a completely stock device

1. **Boot Android:** open the boot menu and set the boot mode to Android. Holodor stays untouched on the device.
2. **Remove Holodor:** boot from the SD card, open the Holodor Installer in Desktop Mode, and choose **Remove Holodor**.
3. **Restore the stock bootloader:** after step 2, boot Android, copy your `abl_a.img` and `abl_b.img` backups into `Internal storage/rocknix_abl`, and run `restore_backup_abl.sh` from **Run script as Root**.

---

## Troubleshooting

* **Black screen after the boot logo:** wrong screen revision selected in the boot menu (Part II, step 9). Reboot into the boot menu and switch between **Retroid Pocket 5** and **Retroid Pocket 5 Visionox**.
* **No Wi-Fi networks listed on first boot:** wait a minute and check again; if none appear, make sure your two-letter `country=` code is set or connect with a wired USB-C hub.
* **Steam says it cannot reach the internet after waking from sleep:** give Wi-Fi a few seconds to reconnect, or toggle Wi-Fi off and back on in Steam's network settings.
* **External monitor comes up at 640x480 with no audio on a USB-C dock:** some HDMI dongles occasionally fail to report their display modes on plug-in. Unplug the dock from the RP5 and plug it back in.

## Appendices

### A. Starting SSH

1. Switch to Desktop Mode and open Konsole.
2. Set a password for the `deck` user: `passwd` (press Enter at the "current password" prompt).
3. Run `systemctl enable --now sshd`.
4. From your PC, run `ssh deck@<the RP5's IP address>`. You can find the IP address in Desktop Mode's network settings or in Steam under **Settings** > **Internet**.
