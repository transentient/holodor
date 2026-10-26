#!/bin/bash
# jack-matrix.sh (2026-10-15): headphone jack state matrix on the UCA202. Each state is written with the sink SUSPENDED (DAPM
# down), then a full-scale 1 kHz tone (level+THD) and the probe+burst file (ducking) are recorded on fusor.
S=${JACK_DIR:-/var/tmp/jack}; H=${RP5:-192.168.1.68}; SINK=alsa_output.platform-sound.HiFi__Headphones__sink
rec() { sudo arecord -q -D hw:CODEC,0 -f S16_LE -c 2 -r 48000 -d $2 $S/$1.wav & R=$!; sleep 1.5; ssh -o BatchMode=yes deck@$H "timeout $(( $2 - 1 )) pw-play --target $SINK /var/tmp/spk/$3"; wait $R; sudo chown cliff $S/$1.wav; }
setc() { local q=""; for a in "$@"; do q="$q '$a'"; done; ssh -o BatchMode=yes deck@$H "sh /var/tmp/spk/hpset.sh $q" | grep -E 'FAILED'; }
state() { ssh -o BatchMode=yes deck@$H "for c in 'RX_COMP1 Switch' 'HPHL_COMP Switch' 'RX HPH Mode' 'RX_HPH PWR Mode' 'HPHL Volume'; do printf '%s=%s ' \"\$c\" \"\$(amixer -c0 cget name=\"\$c\" | grep -oE '^ *: values=.*' | cut -c10-)\"; done; echo"; }
idle() { for i in $(seq 1 15); do st=$(ssh -o BatchMode=yes deck@$H "pw-dump 2>/dev/null | python3 -c \"
import json,sys
for o in json.load(sys.stdin):
    if (o.get('info',{}).get('props',{}) or {}).get('node.name')=='$SINK': print(o['info'].get('state'))
\""); [ "$st" = "suspended" ] && { echo "  sink suspended after $((i*2)) s"; return; }; sleep 2; done; echo "  WARNING sink state '$st' after 30 s"; }
summ() { T=$(python3 $S/thd.py $S/$1.wav 1000 2.6 3.6 | tr '\n' ' '); B=$(python3 $S/env.py $S/$2.wav 1000 220 | awk '$1>=5.4&&$1<=5.6{a=$3} $1>=6.0&&$1<=6.3{b=$3; c=$4} END{printf "probe between %.1f during %.1f -> duck %.1f dB | burst %.1f dBFS", a, b, a-b, c}'); echo "  tone: $T"; echo "  $B"; }
run() { local tag=$1; shift; echo "== $tag"; idle; setc "$@"; printf "  set: "; state; rec ${tag}_tone 8 fs1k.wav; rec ${tag}_burst 9 burst.wav; summ ${tag}_tone ${tag}_burst; }
trap 'idle >/dev/null; setc "RX_COMP1 Switch=1" "RX_COMP2 Switch=1" "HPHL_COMP Switch=0" "HPHR_COMP Switch=0" "RX HPH Mode=CLS_H_ULP" "RX_HPH PWR Mode=LOHIFI"; ssh -o BatchMode=yes deck@$H "wpctl set-volume 52 0.5"; printf "restored (as booted): "; state; echo "sink: $(ssh -o BatchMode=yes deck@$H wpctl get-volume 52)"' EXIT
ssh -o BatchMode=yes deck@$H "wpctl set-volume 52 1.0"; sleep 0.5
run S0_asbooted "RX_COMP1 Switch=1" "RX_COMP2 Switch=1" "HPHL_COMP Switch=0" "HPHR_COMP Switch=0" "RX HPH Mode=CLS_H_ULP" "RX_HPH PWR Mode=LOHIFI"
run SA_1006recipe_off_off_AB_ULP "RX_COMP1 Switch=0" "RX_COMP2 Switch=0" "HPHL_COMP Switch=0" "HPHR_COMP Switch=0" "RX HPH Mode=CLS_AB" "RX_HPH PWR Mode=ULP"
run SB_vendor_on_on_HULP_LOHIFI "RX_COMP1 Switch=1" "RX_COMP2 Switch=1" "HPHL_COMP Switch=1" "HPHR_COMP Switch=1" "RX HPH Mode=CLS_H_ULP" "RX_HPH PWR Mode=LOHIFI"
run SC_off_off_HULP_LOHIFI "RX_COMP1 Switch=0" "RX_COMP2 Switch=0" "HPHL_COMP Switch=0" "HPHR_COMP Switch=0" "RX HPH Mode=CLS_H_ULP" "RX_HPH PWR Mode=LOHIFI"
run SD_off_off_AB_LOHIFI "RX_COMP1 Switch=0" "RX_COMP2 Switch=0" "HPHL_COMP Switch=0" "HPHR_COMP Switch=0" "RX HPH Mode=CLS_AB" "RX_HPH PWR Mode=LOHIFI"
