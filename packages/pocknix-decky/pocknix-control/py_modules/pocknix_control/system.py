import os
import subprocess
import tempfile


def atomically_write(path, text, mode=None):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        if mode is not None:
            os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass


def _clean_env():
    # Until pocknix-decky 18 the loader was upstream's x86_64 PyInstaller bundle under FEX:
    # PyInstaller pointed LD_LIBRARY_PATH at its extracted libs and a child that re-resolved
    # against them died (the FEX-rootfs /bin/sh lost rl_trim_arg_from_keyseq, rc=127).
    # The native decky-loader package sets neither variable, so this is a no-op there; kept
    # so the plugin still behaves under stock Decky (a developer running upstream's bundle).
    env = os.environ.copy()
    orig = env.pop("LD_LIBRARY_PATH_ORIG", None)
    if orig:
        env["LD_LIBRARY_PATH"] = orig
    else:
        env.pop("LD_LIBRARY_PATH", None)
    return env


def run_cmd(cmd, timeout=5, capture=True):
    try:
        return subprocess.run(
            cmd,
            check=False,
            text=True,
            stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            timeout=timeout,
            env=_clean_env(),
        )
    except (OSError, subprocess.SubprocessError):
        return None
