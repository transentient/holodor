"""Fan curves for pocknix-fancontrol (design follows ArmadaOS armada-control, GPL-2.0-or-later).

A curve is "tempC:pwm,tempC:pwm,..." (pwm 0-255), interpolated linearly by the daemon.
Built-in curves are fixed (they mirror the daemon's factory table); user curves live in
/etc/pocknix/fan-curves/<name>.curve as two lines: label, points. The active curve name is
/var/lib/pocknix/fan-mode (see modes.py)."""
import re
from pathlib import Path

from .system import atomically_write

CURVE_DIR = Path("/etc/pocknix/fan-curves")
FAN_MODE_FILE = Path("/var/lib/pocknix/fan-mode")

# Keep in sync with factory_curve() in overlay/usr/local/bin/pocknix-fancontrol.
FACTORY = {
    "quiet": {"label": "Quiet", "curve": "58:0,60:51,65:77,70:102,75:119,80:153,85:204,95:255"},
    "moderate": {"label": "Moderate", "curve": "53:0,55:51,60:77,65:102,70:119,75:153,80:204,85:255"},
    "performance": {"label": "Performance", "curve": "48:0,50:51,55:77,60:102,65:119,70:153,75:204,80:255"},
    "max": {"label": "Max (always 100%)", "curve": "0:255"},
}
FACTORY_ORDER = ("quiet", "moderate", "performance", "max")
DEFAULT = "quiet"

NAME_RE = re.compile(r"^[a-z][a-z0-9_]{0,31}$")
POINT_RE = re.compile(r"^\d{1,3}:\d{1,3}$")
TEMP_MIN, TEMP_MAX = 0, 120
PWM_MIN, PWM_MAX = 0, 255
MAX_POINTS = 16

THERMAL_DIR = Path("/sys/devices/virtual/thermal")


def validate_curve(value):
    """Normalise a curve string: sorted, unique temperatures, in range. Raises ValueError."""
    points = []
    for item in str(value or "").split(","):
        item = item.strip()
        if not item:
            continue
        if not POINT_RE.match(item):
            raise ValueError(f"invalid curve point: {item!r}")
        temp, pwm = (int(v) for v in item.split(":", 1))
        if not (TEMP_MIN <= temp <= TEMP_MAX):
            raise ValueError(f"temperature out of range: {temp}")
        if not (PWM_MIN <= pwm <= PWM_MAX):
            raise ValueError(f"fan speed out of range: {pwm}")
        points.append((temp, pwm))
    if not points:
        raise ValueError("a curve needs at least one point")
    if len(points) > MAX_POINTS:
        raise ValueError(f"a curve can have at most {MAX_POINTS} points")
    points.sort()
    if len({t for t, _ in points}) != len(points):
        raise ValueError("two points share the same temperature")
    return ",".join(f"{t}:{p}" for t, p in points)


def _read_user_curve(path):
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return None
    label = lines[0].strip() if lines else ""
    try:
        curve = validate_curve(lines[1] if len(lines) > 1 else "")
    except ValueError:
        return None
    return {"label": label or path.stem.replace("_", " ").title(), "curve": curve, "factory": False}


def list_curves():
    """Ordered dict: factory curves first, then user curves by name."""
    out = {name: {**FACTORY[name], "factory": True} for name in FACTORY_ORDER}
    try:
        files = sorted(CURVE_DIR.glob("*.curve"))
    except OSError:
        files = []
    for path in files:
        name = path.stem
        if not NAME_RE.match(name) or name in FACTORY:
            continue
        entry = _read_user_curve(path)
        if entry:
            out[name] = entry
    return out


def valid_names():
    return set(list_curves())


def save_curve(name, label, curve):
    name = str(name or "").strip()
    if not NAME_RE.match(name):
        raise ValueError("curve name: lowercase letters, digits and underscores, 32 max, starting with a letter")
    if name in FACTORY:
        raise ValueError(f"'{name}' is a built-in curve; save under another name")
    label = " ".join(str(label or "").split())[:40] or name.replace("_", " ").title()
    normalised = validate_curve(curve)
    atomically_write(CURVE_DIR / f"{name}.curve", f"{label}\n{normalised}\n", 0o644)
    return name


def delete_curve(name):
    name = str(name or "").strip()
    if name in FACTORY or not NAME_RE.match(name):
        raise ValueError("built-in curves cannot be deleted")
    path = CURVE_DIR / f"{name}.curve"
    try:
        path.unlink()
    except FileNotFoundError:
        pass
    # The daemon would fall back to quiet on its own; make the persisted choice say so too.
    try:
        if FAN_MODE_FILE.read_text(encoding="utf-8").strip() == name:
            atomically_write(FAN_MODE_FILE, DEFAULT + "\n", 0o644)
    except OSError:
        pass


def _hottest_temp():
    """Hottest cpu/gpu zone in C, the same reading the daemon drives the fan from."""
    best = None
    try:
        zones = THERMAL_DIR.glob("thermal_zone*")
    except OSError:
        return None
    for zone in zones:
        try:
            kind = (zone / "type").read_text(encoding="utf-8").strip()
            if not (kind.startswith("cpu") or kind.startswith("gpu")):
                continue
            value = int((zone / "temp").read_text(encoding="utf-8").strip())
        except (OSError, ValueError):
            continue
        if best is None or value > best:
            best = value
    return None if best is None else round(best / 1000)


def _fan_pwm():
    for path in sorted(Path("/sys/class/hwmon").glob("hwmon*/pwm1")):
        try:
            return int(path.read_text(encoding="utf-8").strip())
        except (OSError, ValueError):
            continue
    return None


def fan_status():
    pwm = _fan_pwm()
    return {
        "temp": _hottest_temp(),
        "pwm": pwm,
        "percent": None if pwm is None else round(pwm * 100 / PWM_MAX),
    }
