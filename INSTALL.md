# Installing Holodor on the AYN Odin 3

You have two options for running Holodor:
* **From the SD card:** Perfect for trying it out. Your Android setup remains completely untouched.
* **On internal storage, alongside Android:** This is much faster. Android will still be bootable from the menu, but please note that the installation process will factory reset Android once.

Both methods require the one-time boot menu setup found in Part II. To get started, complete Part I, then Part II, and finally Part III. Part IV is completely optional. If you are already running ArmadaOS or ROCKNIX, just do Part I and then skip straight to the "Coming from ArmadaOS or ROCKNIX" section.

A quick heads-up about your first boot: Holodor will download Steam and let it update in the background. While this is happening (usually about 30 to 45 minutes), the menus will lag and your storage will work hard. This only happens once! Note that this is a little different from the ArmadaOS experience, as they ship with a client pre-installed.

---

## What you need

* An **AYN Odin 3**.
* A **microSD card** (32 GB or larger). The bootloader can be surprisingly picky about SD cards. For instance, I found that a couple of newer Silicon Power A2 cards wouldn't work at all. Part II, step 8 will help you confirm if your card is compatible.
* A PC with an SD card reader.
* The Holodor image: `https://holodor.bonesaw.com/holodor-odin3-20260925-seedless.img.zst` (3.1 GB) and its checksum file `https://holodor.bonesaw.com/holodor-odin3-20260925-seedless.img.zst.sha256`.

---

## Part I - Write the SD card

1. Download both the image and the checksum file into the same folder on your PC.
2. Verify the download:
    * **Linux or Mac:** Run `sha256sum -c holodor-odin3-20260925-seedless.img.zst.sha256`
    * **Windows:** Run `certutil -hashfile holodor-odin3-20260925-seedless.img.zst SHA256` and visually compare the output to the contents of the checksum file.
3. Write the image to your SD card.
    * **Linux or Mac:** Run `zstd -d holodor-*.img.zst`, and then `sudo dd if=holodor-*.img of=/dev/sdX bs=4M conv=fsync status=progress`. Please triple-check your `/dev/sdX` path, as this command will entirely erase the target disk!
    * **Windows:** Decompress the file, then write the `.img` using Rufus or balenaEtcher.
    * If your flashing tool asks to verify the write, it is a good idea to let it do so.
4. Once finished, your PC will show a small new partition on the SD card containing a folder named `rocknix_abl`. Leave this right where it is; you will need it for Part II.

---

## Part II - Set up the boot menu (one time, from stock Android)

This step flashes the ROCKNIX bootloader, giving you a handy menu at startup to choose between Android, Linux from the SD card, or Linux from internal storage. It only replaces two tiny bootloader partitions, and we will back those up first. Your Android system is not wiped or modified here.

1. First, remove your Google account: go to **Settings** > **Passwords, passkeys & accounts** > **[your account]** > **Remove account**. Next, remove your screen lock: **Settings** > **Security** > **Screen lock** > **None**.
    * *Why?* If these are left on, Android's security features will lock you out after the factory reset in Part IV. You can easily add them back after Holodor is fully installed.
2. If Android prompts you for a system update, politely decline it. Android updates tend to break dual-boot setups.
3. Insert the prepared SD card into your Odin 3 while Android is running. If it asks how to use the card, select portable storage.
4. Open the Android **Files** app, navigate to the SD card, and copy the entire `rocknix_abl` folder over to the top level of your **Internal storage**.
5. Back up your bootloader: Go to **Settings** > **Odin settings** (near the bottom, under "Google") > scroll to the bottom > **Run script as Root** > `Internal storage/rocknix_abl/backup_abl.sh`.
    * *Important:* The script runner will always tell you it succeeded, even if it failed. You must manually check! Open the Files app and ensure the `rocknix_abl` folder on the SD card now contains `abl_a.img` and `abl_b.img` (about 1 MB each).
    * Copy those two specific files to your PC for safekeeping. There is nowhere else on the internet to download a stock Odin 3 bootloader.
    * Please do not edit the scripts, and be careful not to tap "Enter setup wizard" by mistake.
6. Flash the new bootloader: Go back to **Run script as Root** > `flash_abl.sh`.
7. Power off the device (hold the Power button, select Power off, and wait ten seconds). Then, hold **Volume Down** and press **Power**. You should see a text-based boot menu. If Android boots up normally instead, just repeat step 6.
8. In the new boot menu, open **System Stats**. If it lists your SD card, your card is compatible! If it says no card is inserted, unfortunately, that specific card cannot be booted from. You will need to repeat Part I with a different card (older or slower cards usually work best). If you see a device model setting in the menu, make sure it is set to **AYN Odin 3**.
9. Turn off Android updates: Select **boot mode Android** in the menu, start the device, and run the `disable_android_updates.sh` script using the same "Run script as Root" method from step 5. (If you ever need them back, `enable_android_updates.sh` is there for you).

*To boot Android at any time going forward: open the boot menu, set the boot mode to Android, and hit start.*

---

## Part III - First boot from the SD card

1. Hold **Volume Down** and press **Power**. In the boot menu, set the boot mode to **Linux**. If there is a boot source setting, make sure it is set to **SD card**. Select Start.
2. Be patient. After the initial boot art, the screen will go dark for up to two minutes while the file system prepares the card. Please do not press the power button during this time. If absolutely nothing happens after three full minutes, hold Power for fifteen seconds to shut down, then try booting again.
3. The device needs an internet connection to download Steam. You can provide this in one of two ways:
    * **wifi.txt (Recommended):** Put the SD card back in your PC. You will see one accessible drive (the one with the `rocknix_abl` folder). Create a simple text file named `wifi.txt` there, and type in:
      ```text
      ssid=YourNetworkName
      password=YourWifiPassword
      country=US
      ```
      *(Note: `country` is your two-letter country code, which is required for 5 GHz networks.)* Put the card back into the Odin and boot. Once it connects successfully, the file will automatically rename itself to `wifi.txt.imported`. If something goes wrong, you will find a `wifi-import-error.txt` file explaining why.
    * **Wired Connection:** Plug in a USB-C hub or dock with an ethernet cable attached. Leave it plugged in until Steam has started and you have connected to your Wi-Fi via Steam's network settings. It is safe to power the device off with the hub attached, but do not let the device go to sleep with it attached; the USB port will not wake up properly until you reboot.
4. The download screen will show you its progress. This can take just a few minutes on a fast SD card, or up to an hour on a slower one. If you need to power off mid-download, it is perfectly safe; it will just pick up where it left off next time.
5. Sign in to Steam. Immediately after you sign in, Steam will update itself. The menus will feel laggy and the storage will grind for about 10 to 20 minutes. Just give it some time to finish.
6. You made it! You are now in Steam. Your controls, sound, and rumble are fully functional. A short press of the Power button will put the device to sleep.

*Custom Settings:* If you want to adjust the thumbstick RGB (which is off by default), fan curves, power profiles, experimental charge limits, or Frame Insertion, you can find all of these in **Quick Access > Decky > Pocknix Control**. (Note: Frame Insertion requires you to have the paid Steam app 'Lossless Scaling' installed on the device).

---

## Part IV - Install to internal storage (optional, but recommended)

This installer cleanly shrinks Android's data partition to make room for Holodor right beside it. Remember, this will factory reset your Android setup one time, but the rest of the Android system remains perfectly intact.

1. Boot Holodor from the SD card and ensure you are connected to Wi-Fi or a wired hub.
2. Switch to Desktop Mode by opening the **Steam menu > Power > Switch to Desktop**.
3. Open the Holodor Installer: **Application menu (bottom left) > System > Holodor Installer**.
4. Select **Install Holodor to internal storage**. You will be asked how much space to leave for Android (32 GB is a very sensible minimum). If the installer asks if you want to clear Android's account marker, say yes.
5. Confirm your choices and wait 20 to 30 minutes. Please do not power off the device during this process.
6. Once it finishes, power off the device completely. Remove the SD card, then power it back on. Holodor will now boot directly from your blazing fast internal storage.

Keep that SD card safe! It is your permanent rescue system. Removing Holodor or restoring the stock bootloader in the future is handled directly from that card.

*To boot Android after doing this:* Hold **Volume Down** while powering on and select **Android** in the boot menu. Android will run its first-time setup again. Be sure to decline any Android system updates.

---

## Coming from ArmadaOS or ROCKNIX

Since you already have the custom boot menu installed, you get to skip almost all of Part II (except for step 9, which you should do if you haven't turned off Android updates yet).

1. Complete Part I to write the image to your SD card.
2. Copy your stock bootloader backup to the new Holodor card. Grab `abl_a.img` and `abl_b.img` from the `rocknix_abl/SM8750` folder on your old Armada/ROCKNIX card (or from your PC backup) and drop them into the `rocknix_abl` folder on the new Holodor card.
3. Complete Part III. When in the boot menu, ensure you manually set the boot source to **SD card**, otherwise your old internal Armada or ROCKNIX system will boot instead.
4. To install Holodor to your internal storage in place of Armada/ROCKNIX, proceed to Part IV. The installer will automatically detect your old setup and offer a **Replace with Holodor** option. This will erase the old Linux install and take over its space. Your Android partition will not be resized or reset during this swap! (Just remember to back up any game saves from your old install first).

*Side-by-Side:* If you want to test Armada and Holodor side by side, simply keep a separate SD card for each and use the boot menu to select your SD card as the boot source. You cannot fit Android, ArmadaOS, and Holodor on the internal storage all at the same time.

*Going back to ArmadaOS:* If you decide to revert, open the boot menu and select **UNINSTALL CFW & EXPAND USERDATA** (this removes Holodor and factory resets Android). Then, install Armada from its SD card just like a fresh install. Armada's current installer doesn't recognize Holodor's custom partitions, so it cannot cleanly replace them on its own.

---

## Part V - Going back to Android, or to a completely stock device

1. **Boot Android:** Open the boot menu and set the boot mode to Android. Holodor will stay safely on the device.
2. **Remove Holodor:** Boot from your SD card, open the Holodor Installer in Desktop mode, and choose **Remove Holodor**. If Holodor is currently running from your internal storage, the app will first ask you to select **Disable internal boot**. Click that, power off the device, boot from the SD card again, and open the app one more time to finish the removal. Android will reclaim all the disk space and perform a factory reset. Power off, remove the SD card, boot Android, and let it run its initial setup.
3. **Restore the stock bootloader:** After completing step 2 and verifying that Android boots correctly, boot from your SD card one last time. Open the Holodor Installer and choose **Restore stock bootloader**. It will use the backup files you placed on the card earlier (or let you select a folder where they are saved). After this, your device will boot straight into Android just like the day you bought it, and the custom boot menu will be gone.

**A note about the red "Your device is corrupt" screen:** Once the stock bootloader is restored, the Odin 3 will display this scary-looking warning every time you turn it on. This happens simply because the bootloader is officially "unlocked." Your device is absolutely not corrupt. It will automatically restart on its own after a few seconds, or you can quickly tap the power button to skip the wait. This warning will only go away permanently if AYN releases a firmware update that relocks the bootloader.

---

## Part VI - Restore stock Android with AYN's factory firmware

You should only use this extreme measure if Android itself absolutely refuses to boot. This process forcefully rewrites every single partition on the device from scratch: the stock bootloader returns, Holodor is obliterated, and Android is completely factory reset. Your SD card will not be affected.

You will need:
* A Linux PC with Python 3 installed, and a reliable USB-C cable.
* The `edl` tool: `https://github.com/bkerler/edl` (install it following the instructions in its README).
* AYN's factory firmware package for the Odin 3 (the folder will be named something like `Odin3_20251206`). AYN does not publicly host this file. We found our copy via a Google Drive link floating around in the `odin3-linux` channel on the official AYN Discord server.

1. Unzip the factory package. Inside, you should find a loader file named `xbl_s_devprg_ns.melf`, alongside several `rawprogram*.xml` and `patch*.xml` files, plus the actual partition images.
2. On your Linux PC, run: `sudo modprobe -r qcserial usb_wwan`. (If you skip this, a default kernel driver will aggressively grab the device connection).
3. Put the Odin 3 into EDL mode: Power the device off and wait a full ten seconds after the screen goes completely dark. Unplug the USB cable if it's connected. Press and hold **Volume Up** and **Volume Down** together, plug the USB cable in while holding both buttons, count to five slowly, and then release them. Running `lsusb` on your PC should now show a device listed as `05c6:9008`.
4. Run a read-only check to ensure your PC is talking to the device correctly. Run this from inside the unzipped package folder:
   ```bash
   sudo edl printgpt --memory=ufs --loader=xbl_s_devprg_ns.melf
   ```
5. Now, flash the entire package in a single command. If you are using the Dec-2025 package, the exact command looks like this:
   ```bash
   sudo edl qfil rawprogram_unsparse0.xml,rawprogram1.xml,rawprogram2.xml,rawprogram3.xml,rawprogram_unsparse4.xml,rawprogram5.xml patch0.xml,patch1.xml,patch2.xml,patch3.xml,patch4.xml,patch5.xml . --memory=ufs --loader=xbl_s_devprg_ns.melf
   ```
   *Note: If you have a different firmware package version, just make sure to list all of its `rawprogram*.xml` files and `patch*.xml` files in the exact same format. Never try to flash only a few of them.*
   ⚠️ **Warning:** Do not touch any buttons on the device while this command is running. Never hold the power button for more than ten seconds during any EDL step, as this will perform a hard hardware reset and corrupt the flash process mid-stream.
6. Once finished, you must manually erase the Google account marker (the factory package forgets to do this):
   ```bash
   sudo edl e frp --memory=ufs --lun=0 --loader=xbl_s_devprg_ns.melf
   ```
   If you skip this step, Android will trap you in a boot loop with a screen saying "Factory reset this device" and a useless Reset button.
7. Restart the device by running: `sudo edl reset`
8. With the USB cable still plugged in, the red "Your device is corrupt" screen will pop up. Tap the Power button once. If a battery charging icon appears instead, simply hold the Power button for about three seconds until the AYN logo shows up. Android will now boot up and take you to the standard first-time setup screen.

---

## Troubleshooting

* **Boot menu says "SD card not inserted":** The bootloader unfortunately can't read the card you're using. Try an older or slower micro SD card.
* **"DEVICE MODEL NOT SET" after a bootloader update:** You just need to select it again (see Part II, step 8).
* **"DEVICE MODEL NOT SET" and AYN Odin 3 is not in the list (the list only scrolls part way):** Your card was written from an image older than 20260925. Download the current image from the top of this guide and repeat Part I. The bootloader you already flashed is fine.
* **Android shows "Factory reset this device" and only gives a Reset button:** Boot from your SD card, open the Holodor Installer in Desktop mode, click **Fix Android setup lock**, and then boot back into Android.
* **Red "device is corrupt" screen keeps restarting:** This is completely normal when you have an unlocked bootloader. Just give the power button a quick short tap to skip the warning screen.
* **Black screen for a minute or two on first boot:** Don't worry, it is working in the background. (See Part III, step 2).
* **Stuck at Steam sign-in with a spinning QR code:** Give it 2 to 3 minutes to sort itself out. If it is still stuck after 10 minutes, hold Power for 15 seconds to force a reboot and try again.
* **Wi-Fi shows connected but absolutely nothing loads:** Go into Settings and toggle your Wi-Fi off and then back on.
* **A game froze and all buttons are dead:** Short-press the Power button to put the device to sleep, then press it again to wake it up. To avoid this happening in the future, try opening the game's internal pause menu before pulling up the Steam overlay.
* **Neither system will boot and the text boot menu appears every single time:** Connect to a PC with fastboot installed and run `fastboot set_active a` (or `b`).
* **Device is completely wedged or unresponsive:** Hold the Power button for 15 solid seconds to force a hard reset, then boot again.

---

## Appendices

### A. Starting SSH

For security, SSH is completely disabled on every fresh Holodor image, and the default `deck` user doesn't even have a password. There is nothing to log into until you choose to set it up. If you want remote access, here is how to turn it on:

1. Switch over to Desktop Mode and open the terminal app, Konsole.
2. Set a password for the `deck` user by typing `passwd` and pressing Enter. When it asks for your "current password", just press Enter again (since there isn't one). Then, type your new password twice.
3. Turn SSH on immediately and set it to start at every boot: `systemctl enable --now sshd`
4. From your PC, you can now connect using: `ssh deck@<the Odin's IP address>`. You can find the device's IP address in Desktop Mode under **Settings** > **Network**.

Please note that there is no `sudo` available by default and the root account is completely locked down. If you absolutely need a root shell from the `deck` account, you can run: `systemd-run --wait --pipe -t /bin/bash`

### B. Running the installer's tools from the command line

If you prefer the terminal, everything the graphical Holodor Installer app does can also be run as a command from a root shell:

* `pocknix-install-internal`: Installs Holodor to the internal storage. Add the `--replace` flag if you want to take over an existing Linux installation without touching the Android partition.
* `pocknix-uninstall-internal`: Removes Holodor cleanly from the internal storage.
* `pocknix-clear-frp`: Clears Android's account marker (this does the exact same thing as the "Fix Android setup lock" button).
* `pocknix-restore-stock-abl`: Restores your stock bootloader. You can append `--from DIR` to point it to a backup saved in a specific folder.

*Safety feature:* Every one of these commands will happily print out its plan first if you add `--dry-run` (or `--check` / `--find` for the latter two). They will not actually change anything on your system until you run them without those flags.
