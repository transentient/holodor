#!/bin/sh
# press A (only A) every 2.5 s for $1 seconds
end=$(( $(date +%s) + $1 ))
while [ $(date +%s) -lt $end ]; do
  timeout 5 busctl --system --timeout=4 call org.shadowblip.InputPlumber /org/shadowblip/InputPlumber/CompositeDevice0 org.shadowblip.Input.CompositeDevice SendButtonChord as 1 Gamepad:Button:South >/dev/null 2>&1
  sleep 2.5
done
