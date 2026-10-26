#!/bin/bash
# abshot.sh [name] -> /tmp/ab-<name>.png via gamescope (run as deck)
n=${1:-shot}; rm -f /tmp/ab-$n.png; gamescopectl screenshot /tmp/ab-$n.png >/dev/null 2>&1; sleep 1.5; ls -la /tmp/ab-$n.png
