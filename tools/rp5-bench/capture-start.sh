#!/bin/sh
# usage: capture-start.sh <run-name> [launch]   -> ~/rp5-vs-hang/<run-name>/{journal,samples}.log
D=$HOME/rp5-vs-hang/$1; mkdir -p "$D"
systemctl --user stop rp5-journal rp5-sampler 2>/dev/null
SSH="ssh -o ServerAliveInterval=5 -o ServerAliveCountMax=6 deck@192.168.1.68"
scp -q "$HOME/rp5-vs-hang/bin/rp5-sampler.sh" deck@192.168.1.68:rp5-sampler.sh
systemd-run --user --quiet --unit=rp5-journal --collect sh -c "$SSH 'systemd-run --quiet --wait --pipe --collect journalctl -f -n 0 -o short-monotonic' > $D/journal.log 2>&1"
systemd-run --user --quiet --unit=rp5-sampler --collect sh -c "$SSH 'sh ~/rp5-sampler.sh' > $D/samples.log 2>&1"
sleep 3
if [ "$2" = launch ]; then $SSH 'echo "steam://run/1794680" > ~/.steam/steam.pipe' && echo "launched VS"; fi
echo "capturing to $D"
