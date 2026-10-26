# desktop-eye: see and touch the Odin's Desktop Mode over ssh (dev only)

Built 2026-10-02 to test the on-screen keyboard without Cliff holding the device.

- `odinshot.sh <name>`: screenshot through KWin's ScreenShot2 D-Bus interface -> `<name>.png` (960x540)
  next to the script. Needs `kwinshot.py` at `/tmp/kwinshot.py` on the device and KWin started with
  `KWIN_SCREENSHOT_NO_PERMISSION_CHECKS=1`:

      mkdir -p ~/.config/systemd/user/plasma-kwin_wayland.service.d
      printf '[Service]\nEnvironment=KWIN_SCREENSHOT_NO_PERMISSION_CHECKS=1\n' \
        > ~/.config/systemd/user/plasma-kwin_wayland.service.d/claude-shot.conf
      systemctl --user daemon-reload; steamos-session-select desktop    # restarts the desktop

  Remove the drop-in when done (it lets any local process take screenshots). The call must be
  asynchronous: a blocking D-Bus call deadlocks against KWin writing the pixels into the pipe.
- `odintap.sh SX SY [SX SY ...]`: finger taps at screenshot coordinates, through a uinput virtual
  touchscreen (`vtap.py` at `/tmp/vtap.py` on the device, run as root with `systemd-run`). KWin applies
  the panel rotation to it: dev_x = 1 - sy, dev_y = sx (measured). Touch must be the last input used
  or KWin will not show the on-screen keyboard, so test keyboard behaviour with taps, not D-Bus alone.
- `kmsgrab` in the device's ffmpeg does not work on this panel; spectacle and grim are not installed.
