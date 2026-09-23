from pathlib import Path

from .system import atomically_write, run_cmd

# Both mode files live in /var/lib/pocknix and hold one bare word; both daemons treat an
# unknown/absent value as the default, so a bad write degrades gracefully.
FAN_MODE_FILE = Path("/var/lib/pocknix/fan-mode")
LAVD_MODE_FILE = Path("/var/lib/pocknix/lavd-mode")
POWER_MODE_FILE = Path("/var/lib/pocknix/power-mode")
DOWNLOAD_INHIBIT_FILE = Path("/var/lib/pocknix/download-inhibit-mode")

FAN_DEFAULT = "quiet"   # curve names: built-in + user curves, see fan_curves.py
LAVD_MODES = ("autopilot", "performance")
LAVD_DEFAULT = "autopilot"
POWER_MODES = ("eco", "balanced", "performance")
POWER_DEFAULT = "performance"
DOWNLOAD_INHIBIT_MODES = ("always", "plugged", "never")
DOWNLOAD_INHIBIT_DEFAULT = "always"


def _read_mode(path, allowed, default):
    try:
        mode = path.read_text(encoding="utf-8").strip()
    except OSError:
        return default
    return mode if mode in allowed else default


def fan_mode():
    from .fan_curves import valid_names
    return _read_mode(FAN_MODE_FILE, valid_names(), FAN_DEFAULT)


def lavd_mode():
    # pocknix-lavd-mode also accepts balanced/powersave for experiments; the UI only
    # offers autopilot/performance, so map anything else back to the default.
    return _read_mode(LAVD_MODE_FILE, LAVD_MODES, LAVD_DEFAULT)


def power_mode():
    return _read_mode(POWER_MODE_FILE, POWER_MODES, POWER_DEFAULT)


def set_power_mode(mode):
    if mode not in POWER_MODES:
        raise ValueError(f"unknown power mode: {mode!r}")
    # The helper applies cpu/gpu caps immediately and persists the mode itself.
    run_cmd(["/usr/local/bin/pocknix-power-mode", mode])


def download_inhibit_mode():
    return _read_mode(DOWNLOAD_INHIBIT_FILE, DOWNLOAD_INHIBIT_MODES, DOWNLOAD_INHIBIT_DEFAULT)


def set_download_inhibit_mode(mode):
    if mode not in DOWNLOAD_INHIBIT_MODES:
        raise ValueError(f"unknown download inhibit mode: {mode!r}")
    # pocknix-download-inhibit re-reads this file every loop (<= 45 s); no restart needed.
    atomically_write(DOWNLOAD_INHIBIT_FILE, mode + "\n", 0o644)


def set_fan_mode(mode):
    from .fan_curves import valid_names
    if mode not in valid_names():
        raise ValueError(f"unknown fan curve: {mode!r}")
    # pocknix-fancontrol re-reads this file every curve tick (~3s); no restart needed.
    atomically_write(FAN_MODE_FILE, mode + "\n", 0o644)


def set_lavd_mode(mode):
    if mode not in LAVD_MODES:
        raise ValueError(f"unknown lavd mode: {mode!r}")
    # The helper persists the mode and restarts pocknix-lavd.service (live scheduler swap).
    proc = run_cmd(["/usr/local/bin/pocknix-lavd-mode", mode], timeout=30)
    if proc is None:
        raise RuntimeError("pocknix-lavd-mode failed to spawn")
    if proc.returncode != 0:
        raise RuntimeError(f"pocknix-lavd-mode failed (rc={proc.returncode}): {(proc.stderr or '').strip()[:300]}")


# --- battery charge limit (care thresholds the kernel honors: stop charging at
#     END, resume at START; "100" = charge to full / limit off) ---
_BATT = Path("/sys/class/power_supply/battery")
CHARGE_LIMITS = (80, 85, 90, 100)
CHARGE_DEFAULT = 100


def charge_limit():
    try:
        v = int((_BATT / "charge_control_end_threshold").read_text().strip())
    except (OSError, ValueError):
        return CHARGE_DEFAULT
    return v if v in CHARGE_LIMITS else CHARGE_DEFAULT


def set_charge_limit(pct):
    pct = int(pct)
    if pct not in CHARGE_LIMITS:
        raise ValueError(f"charge limit {pct} not in {CHARGE_LIMITS}")
    # start ~10 below end (hysteresis); 100 disables the limit (start=95 avoids churn).
    start = 95 if pct >= 100 else pct - 10
    try:
        (_BATT / "charge_control_end_threshold").write_text(f"{pct}\n")
        (_BATT / "charge_control_start_threshold").write_text(f"{start}\n")
    except OSError:
        pass  # non-fatal: kernel/hardware may not expose it


# --- thumbstick RGB (HTR3212 rings via pocknix-stick-leds) ---
LED_COLOR_FILE = Path("/var/lib/pocknix/led-color")
LED_MODE_FILE = Path("/var/lib/pocknix/led-mode")
LED_DEFAULT = "ff6600"
LED_MODES = ("off", "static", "rainbow", "breathe")
LED_MODE_DEFAULT = "off"


def led_color():
    try:
        c = LED_COLOR_FILE.read_text().strip()
    except OSError:
        return LED_DEFAULT
    return c if c else LED_DEFAULT


def set_led_color(hexcolor):
    hexcolor = str(hexcolor).lstrip("#").lower()
    if len(hexcolor) != 6 or any(c not in "0123456789abcdef" for c in hexcolor):
        raise ValueError(f"bad led color: {hexcolor!r}")
    run_cmd(["/usr/local/bin/pocknix-stick-leds", "save", hexcolor])


def led_mode():
    try:
        m = LED_MODE_FILE.read_text().strip()
    except OSError:
        return LED_MODE_DEFAULT
    return m if m in LED_MODES else LED_MODE_DEFAULT


def set_led_mode(mode):
    if mode not in LED_MODES:
        raise ValueError(f"bad led mode: {mode!r}")
    run_cmd(["/usr/local/bin/pocknix-stick-leds", "mode", mode])
