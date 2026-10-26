#!/bin/bash
# abrun.sh <label> [fromresults] — run the Cyberpunk built-in benchmark once from the Graphics tab
# (or from the results screen if 2nd arg given: clicks Settings first), sampler on, screenshot of results.
l=$1; [ -n "$2" ] && { abmouse.py 270 591 click >/dev/null 2>&1; sleep 3; }
systemd-run --quiet --unit=absample-$l-$(date +%s) --collect absample.sh $l 125
sleep 1; abkey.py b sleep:1.5 enter; echo "$l started $(date +%H:%M:%S)"
sleep 116; su deck -c "abshot.sh $l-res" >/dev/null 2>&1 || sudo -u deck abshot.sh $l-res >/dev/null 2>&1
ls -la /tmp/ab-$l-res.png | cut -c25-
