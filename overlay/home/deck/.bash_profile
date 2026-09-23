# pocknix-os — session supervisor (non-root 'deck' autologin on tty1).
# getty@tty1 autologins 'deck', giving a REAL login session (XDG_RUNTIME_DIR=/run/user/1001 + the
# per-user PipeWire stack). PipeWire only runs for a non-root user, which is why the session user is
# 'deck'. This script is the session SUPERVISOR.
#
# It is a LOOP, not an `exec`: it launches the chosen session and, when that compositor exits,
# re-reads the choice file and launches the next one — all while THIS bash stays the session leader,
# so the single logind session stays `active` on seat0 the whole time. That is the fix for switching:
# previously the switch did `systemctl restart getty@tty1`, which tore down + recreated the login
# session; kwin then inherited a stale/closed logind session id ("login1/session/_NN Unknown object")
# and could not become DRM master ("atomic commit failed: Permission denied"), so Plasma hung on a
# black/console screen. Keeping one long-lived session makes every switch behave like a cold boot.
#
# Switching: steamos-session-select writes the choice file ($XDG_STATE_HOME/pocknix-session =
# gamescope|plasma) and SIGTERMs the current compositor; this loop then relaunches into the new
# choice. No getty restart, no polkit. Default = gamescope (game mode); desktop is opt-in.
#
# Guards: physical console (tty1) only, NOT over SSH or other VTs. Escape hatch: `touch ~/.no-steam`
# to get a plain shell on tty1 for debugging.
if [ "$(tty)" = "/dev/tty1" ] && [ -z "${SSH_CONNECTION:-}" ] && [ ! -e "${HOME}/.no-steam" ]; then
  POCKNIX_STATE="${XDG_STATE_HOME:-${HOME}/.local/state}/pocknix-session"
  # tty1 is what shows in the gap between compositors (session switch / crash), so keep it BLANK:
  # hide the cursor + clear before every launch, and send session output to a log, not the console
  # (gamescope/Steam/Plasma are chatty; their scrollback used to replay across every switch). The
  # cursor is restored on the drop-to-shell path so debugging stays usable.
  POCKNIX_SESSION_LOG="${HOME}/pocknix-session.log"
  pocknix_fastfails=0
  while true; do
    POCKNIX_SESSION="$(cat "${POCKNIX_STATE}" 2>/dev/null || echo gamescope)"
    pocknix_start="$(date +%s)"
    printf '\033[?25l\033[2J\033[H'
    # Splash-hold: plymouth-quit{,-wait} are disabled in the image, so the boot
    # splash (holding the badge frame) is still ours here. Release it with
    # --retain-splash right before the compositor takes DRM: the held frame stays
    # on the panel through the handoff, closing the ~20s black gap (and hiding the
    # getty flash). No-op after first launch / when plymouthd isn't running.
    # Day-one polish: let the boot cutscene FINISH before the panel is handed over. The holodor
    # theme preloads ~1 s then plays 3.4 s (34 frames at 10 fps), so the first launch waits
    # until plymouthd has been up POCKNIX_CUTSCENE_SECS (default 5) seconds. Costs nothing on a
    # slow SD boot (the session is later anyway), a second or two on internal storage.
    if [ -z "${pocknix_cutscene_waited:-}" ]; then
      pocknix_cutscene_waited=1
      pocknix_plymouth_pid="$(pidof plymouthd 2>/dev/null | awk '{print $1}')"
      if [ -n "${pocknix_plymouth_pid}" ]; then
        pocknix_up="$(ps -o etimes= -p "${pocknix_plymouth_pid}" 2>/dev/null | tr -d ' ')"
        pocknix_need="${POCKNIX_CUTSCENE_SECS:-5}"
        if [ -n "${pocknix_up}" ] && [ "${pocknix_up}" -lt "${pocknix_need}" ] 2>/dev/null; then
          sleep "$(( pocknix_need - pocknix_up ))"
        fi
      fi
    fi
    plymouth quit --retain-splash 2>/dev/null || true
    case "${POCKNIX_SESSION}" in
      plasma|desktop) command -v pocknix-desktop >/dev/null 2>&1 && pocknix-desktop >"${POCKNIX_SESSION_LOG}" 2>&1 ;;
      *)              command -v pocknix-steam   >/dev/null 2>&1 && pocknix-steam   >"${POCKNIX_SESSION_LOG}" 2>&1 ;;
    esac
    # A session that exits in <5s is almost certainly broken (missing stack, crash). Tolerate the
    # odd quick exit, but if it happens 3x in a row drop to a shell instead of hot-looping.
    if [ "$(( $(date +%s) - pocknix_start ))" -lt 5 ]; then
      pocknix_fastfails="$(( pocknix_fastfails + 1 ))"
      if [ "${pocknix_fastfails}" -ge 3 ]; then
        # Reveal the console (splash may still be up if the first launch died).
        plymouth quit 2>/dev/null || true
        printf '\033[?25h'
        echo "pocknix: session '${POCKNIX_SESSION}' keeps exiting immediately — dropping to a shell." >&2
        echo "        (fix it, then re-login; or 'touch ~/.no-steam' to stay at a shell.)" >&2
        echo "        (session output is in ${POCKNIX_SESSION_LOG})" >&2
        break
      fi
    else
      pocknix_fastfails=0
    fi
  done
  printf '\033[?25h'
fi

# Escape hatch on tty1 (~/.no-steam): the session loop never ran, so nothing
# released the boot splash — reveal the console for debugging.
if [ "$(tty)" = "/dev/tty1" ] && [ -e "${HOME}/.no-steam" ]; then
  plymouth quit 2>/dev/null || true
fi
