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
    # Splash handoff: the boot splash (root's plymouth-quit.service, held by
    # pocknix-cutscene-wait) is released the moment this flag appears, so login and
    # systemd --user ran under the logo instead of on a black panel. Then wait for plymouthd
    # to be gone (it holds DRM master; gamescope would get "Device or resource busy") before
    # launching. Nothing here may call `plymouth quit` itself: plymouthd ignores non-root
    # clients (a deck-side quit was silently refused for months, found 2026-09-23).
    # plymouthd probes the terminal as it exits (cursor to 999;999 + a position query);
    # with echo on, the replies "^[[1;1R^[[67;240R" print in the corner for a frame.
    stty -echo 2>/dev/null || true
    touch "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pocknix-session-ready" 2>/dev/null
    pocknix_i=0
    while pidof plymouthd >/dev/null 2>&1 && [ "${pocknix_i}" -lt 150 ]; do
      sleep 0.1; pocknix_i=$(( pocknix_i + 1 ))
    done
    # plymouthd re-shows the console cursor on exit: hide it again, and clear.
    printf '\033[?25l\033[2J\033[H'
    case "${POCKNIX_SESSION}" in
      plasma|desktop) command -v pocknix-desktop >/dev/null 2>&1 && pocknix-desktop >"${POCKNIX_SESSION_LOG}" 2>&1 ;;
      *)              command -v pocknix-steam   >/dev/null 2>&1 && pocknix-steam   >"${POCKNIX_SESSION_LOG}" 2>&1 ;;
    esac
    # A session that exits in <5s is almost certainly broken (missing stack, crash). Tolerate the
    # odd quick exit, but if it happens 3x in a row drop to a shell instead of hot-looping.
    if [ "$(( $(date +%s) - pocknix_start ))" -lt 5 ]; then
      pocknix_fastfails="$(( pocknix_fastfails + 1 ))"
      if [ "${pocknix_fastfails}" -ge 3 ]; then
        # Reveal the console.
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

# Escape hatch on tty1 (~/.no-steam): the session loop never ran — make the console usable.
if [ "$(tty)" = "/dev/tty1" ] && [ -e "${HOME}/.no-steam" ]; then
  printf '\033[?25h'
fi
