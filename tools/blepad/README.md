# blepad: the AtomS3U as a Bluetooth LE gamepad (dev only)

The dock matrix "finger": a real wireless controller for a docked device, driven from fusor.
Hardware: M5Stack AtomS3U (ESP32-S3, BLE only; no classic Bluetooth, so it cannot be an audio sink)
on fusor's USB as /dev/ttyACM0 (Espressif USB-JTAG/serial, group uucp).

- `AtomS3U_BlePad/AtomS3U_BlePad.ino`: ESP32-BLE-Gamepad (lemmingDev, installed from git) + NimBLE.
  Advertises "Holodor BLE Pad" (VID 303a / PID 8001, generic gamepad: 16 buttons, hat, two sticks,
  two triggers). Serial protocol in the sketch header.
- `blepad.sh <cmd>`: one command over serial, prints the reply (`status`, `press A`, `dpad right`,
  `stick L 0.5 0`, `trig R 1`, `hold B` / `release B`).

Toolchain on fusor (user-local, fusor's pacman untouched; 2026-10-10): `~/.local/bin/arduino-cli`
(install.sh), core `esp32:esp32`, libs NimBLE-Arduino + ESP32-BLE-Gamepad (`--git-url
https://github.com/lemmingDev/ESP32-BLE-Gamepad.git`, needs `library.enable_unsafe_install true`),
`~/esp-venv` with esptool + pyserial.
Build + flash: `arduino-cli compile --fqbn esp32:esp32:m5stack_atoms3:CDCOnBoot=cdc AtomS3U_BlePad`
then `sudo ... arduino-cli upload --fqbn ... -p /dev/ttyACM0 AtomS3U_BlePad` (sudo for the port
until cliff's uucp membership is active).
Pair from the device (root): `bluetoothctl scan on` -> "Holodor BLE Pad" -> pair / trust / connect.
Steam grabs the evdev node itself (InputPlumber makes no composite device for it) and switches its
button glyphs to the Xbox style; verified 2026-10-10 on the RP5 docked (language screen highlight
moved with `dpad down`).
