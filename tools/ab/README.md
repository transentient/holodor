# tools/ab — hands-free Cyberpunk benchmark harness for the Odin 3 (holodor)

Built 2026-09-06 for the mesa-next-6 A/B. Install on the device as root into /usr/local/bin
(`install -m755 tools/ab/* /usr/local/bin/`; python-evdev is on the image). Everything runs over ssh
as `deck`, with root via `systemd-run --quiet --wait --pipe`.

| tool | what |
|---|---|
| `abshot.sh NAME` | `gamescopectl screenshot /tmp/ab-NAME.png` (run as deck). x11grab is BLACK under gamescope. |
| `abkey.py KEY…` | uinput keyboard: `enter down left b 3 space meta+f sleep:2 hold:a:500`. Goes to the gamescope-focused window (Steam UI or the game). |
| `abmouse.py X Y [click\|move] [step]` | uinput mouse, 4 px steps (large deltas hit Windows pointer acceleration in the game and land elsewhere). X,Y are X-root coords; the game draws the cursor at 1.5× (1280x720 window scaled to 1920x1080), so target = screenshot coords / 1.5. |
| `abpad.py a b start …` | uinput Xbox pad. Works, but the game shows "controller disconnected" when the script exits — keep it alive for the whole session or use the keyboard. |
| `abxptr.py :1` / `abxtree.py :1` | X pointer position / top-level windows per Xwayland (`:0` = Steam UI, `:1` = the game). Must run as deck. |
| `absample.sh LABEL SECS` | 1 Hz CSV → /var/lib/pocknix/ab/LABEL.csv: presented fps (crtc total_framecount), GPU MHz, GPU busy (fdinfo, unreliable for the FEX game), cpu/gpu temp, W, big-core kHz. |
| `abrun.sh LABEL [fromresults]` | one benchmark run from the Graphics tab (or from the results screen: clicks Settings first), sampler on, 116 s wait. Result = screenshot of the results screen; read the numbers off it. |

Flow that works (each step verified by screenshot the first time):
1. Inhibit sleep FIRST: `systemd-run --unit=holodor-ab-inhibit --collect systemd-inhibit --what=sleep:idle --mode=block sleep 8h`.
2. `pocknix-power-mode max`; `sh /usr/local/bin/pocknix-fan-mode performance` (the fan script lacks +x). Bench mode pins CPU at max → cpu zones read ~100 °C; `rm /var/lib/pocknix/{power,fan}-mode` + reboot restores defaults.
3. Launch skipping REDlauncher: `echo "steam://run/1091500//--launcher-skip/" > ~/.steam/steam.pipe`, ~10 s later `abkey.py enter` for Steam's "custom arguments" dialog. REDlauncher itself is unreachable by any virtual input (gamescope routes input to :0 while it shows).
4. Wait ≥130 s after a reboot (shader warm-up), then `abkey.py space` past the title; the main menu has no highlight until the mouse hovers something: `abmouse.py 160 400 click` = SETTINGS, then `abkey.py 3 3 3` = Graphics tab (from the results screen, Settings reopens directly on Graphics).
5. Config by file, not menus: UserSettings.json (compatdata/1091500/pfx/.../CD Projekt Red/Cyberpunk 2077/) — Resolution "1280x720", ResolutionScaling "Off", VSync already Off, QuickPresets Low; relaunch to apply.
6. `abrun.sh A1`, then `abrun.sh A2 fromresults` …

TRAPS: (a) `pgrep -f`/`pkill -f` with the game name matches your own ssh shell → kill by pid from `pgrep -f "Cyberpunk2077[.]exe"`. (b) A driver swap needs the game QUIT (verify `ps -o lstart= -p PID` changes) AND a reboot: FEXServer keeps the old fex-rootfs sqsh mounted. (c) Verify what the game loaded: `strings /proc/PID/map_files/<libvulkan_freedreno range>` shows the pocknix stamp. (d) `gpg-agent` orphans etc. are fusor-side; irrelevant here.
