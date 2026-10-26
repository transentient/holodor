# rp5-bench: measure game performance on a device in game mode, with nobody holding it (dev only)

Built 2026-10-05 on the Retroid Pocket 5. Everything runs over ssh from fusor.

**Eye**
- `rp5shot.sh <name>`: gamescope screenshot of the game plane (`GAMESCOPECTRL_DEBUG_REQUEST_SCREENSHOT 1`
  -> `/tmp/gamescope.png` on the device). Types 2-4 come back black on this rotated panel.
- `gsframes.py <out.csv> <secs>` (on the device): gamescope's per-frame timings. gamescope sends one SysV
  message per app frame and per displayed frame to mangoapp; this reads the queue (mangoapp is paused
  with SIGSTOP meanwhile, the queue has one reader). The x86 game does not load our arm64 MangoHud layer
  unless MANGOHUD=1 is set, and mangoapp's own logging never produced a file.
- `gsstats.py`, `vis.py`, `gsminutes.py`: summaries. `vis.py` shows how many refresh periods each frame
  stayed on screen, which is what the eye sees as judder.
- `rp5-sampler.sh` (v2.1, streamed by `capture-start.sh <run>`): 1 Hz GPU clock, temperature, the game's
  main-thread CPU and core, GPU busy, shader-compile CPU.

**Finger**
- `rp5pad.sh South East ...`: button presses through InputPlumber's D-Bus `SendButtonChord` (root).
  `SendEvent` panics a worker thread in InputPlumber 0.81; do not use it.
- `presser.sh <secs>` (on the device): presses A every 2.5 s. A ONLY. A version that also pressed
  d-pad down walked into the Power Up shop after a death and spent the save's gold (recovered by
  SIGKILL before the game saved). Keep a copy of `userdata/<id>/<appid>/remote/` before automating a game.
- Launch: `echo steam://run/<appid> > ~/.steam/steam.pipe`. After killing a game, restart the session
  (`steamos-session-select gamescope`) if `GAMESCOPE_FOCUSED_APP` stays 769: Steam keeps input focus and
  the game ignores the pad.

**Method**
- `abtest*.sh <secs> <cond>...` (root, on the device): alternate settings INSIDE one run (ABAB, 30-40 s
  each) so the game's own drift cancels out. `vsbench.sh <label>`: fresh launch, frames from 150 s to 270 s.
- Frame limit for tests: `gamescopectl debug_set_fps_limit <fps>` (needs GAMESCOPE_WAYLAND_DISPLAY=gamescope-0).
  Setting the GAMESCOPE_FPS_LIMIT atom by hand is overridden at once by the newer control path.
