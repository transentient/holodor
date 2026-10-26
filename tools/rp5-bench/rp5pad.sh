#!/bin/sh
# rp5pad.sh <Button> [<Button> ...] : press controller buttons on the RP5 through InputPlumber, one after another
# (names: South East West North Start Select Guide LeftBumper RightBumper DPadUp/Down/Left/Right ...). 0.6 s apart.
R=deck@${RP5:-192.168.1.68}; cmd=""
for b in "$@"; do cmd="$cmd timeout 5 busctl --system --timeout=4 call org.shadowblip.InputPlumber /org/shadowblip/InputPlumber/CompositeDevice0 org.shadowblip.Input.CompositeDevice SendButtonChord as 1 Gamepad:Button:$b; sleep 0.6;"; done
ssh -o ConnectTimeout=6 $R "systemd-run --quiet --wait --pipe --collect sh -c '$cmd'"
