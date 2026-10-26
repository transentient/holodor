#!/bin/bash
# audio-snapshot.sh <label> (2026-10-16), run ON FUSOR: QUIET audio regression snapshot of the RP5 for kernel changes
# that touch the LPASS macros (kernel 48). Run it identically on the old and the new kernel and compare.
# Nothing loud: a -40 dBFS 1 kHz tone, sink volumes pinned to 0.60 for the run and restored afterwards.
#  1. state: kernel, jack controls, sinks/sources (wpctl), every card-0 control (amixer contents)
#  2. idle 25 s first (sink suspended, on kernel 48 the macros power down), so the tone starts from the idle state
#  3. speaker: tone on the default sink; recorded by fusor's NTG mic (~25 cm) AND by the RP5's own default source
#  4. mid-tone: macro registers, cache vs hardware (regsnap.sh on the RP5)
#  5. jack: only if the jack reports a plug and fusor has the UCA202 ("CODEC"): tone on the Headphones sink -> line-in
set -u
L=$1; H=${RP5:-192.168.1.68}; O=${OUT:-$HOME/dock-runs/audio-snapshot/$L}; mkdir -p "$O"
T=$(cd "$(dirname "$0")" && pwd); A=$T/../rp5-audio
RS="sshpass -p pocknix ssh -o ConnectTimeout=6 -o PreferredAuthentications=password root@$H"
RCP="sshpass -p pocknix scp -q -o PreferredAuthentications=password"
DS="ssh -o ConnectTimeout=6 -o BatchMode=yes deck@$H"
ENV='export XDG_RUNTIME_DIR=/run/user/$(id -u);'
NC=$(sed -n 's/^ *\([0-9]\+\) \[NTG *\].*/\1/p' /proc/asound/cards); [ -n "$NC" ] || { echo "no NTG mic on fusor"; exit 1; }
UC=$(sed -n 's/^ *\([0-9]\+\) \[CODEC *\].*/\1/p' /proc/asound/cards)
HPS=alsa_output.platform-sound.HiFi__Headphones__sink

python3 - "$O/snap1k.wav" <<'PY'
import math, struct, sys, wave
fs = 48000; a = 10 ** (-40 / 20) * 32767
w = wave.open(sys.argv[1], "wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(fs)
w.writeframes(b"".join(struct.pack("<hh", *(2 * [int(a * math.sin(2 * math.pi * 1000 * i / fs))])) for i in range(fs * 4)))
PY
$RS "mkdir -p /var/tmp/rp5-power" && $RCP "$T/regsnap.sh" root@$H:/var/tmp/rp5-power/ && $RCP "$O/snap1k.wav" root@$H:/var/tmp/snap1k.wav && $RS "chmod 644 /var/tmp/snap1k.wav"

# 1. state
$RS "uname -r; pacman -Q linux-pocknix-sm8250; amixer -c0 contents" > "$O/amixer.txt"
$DS "$ENV wpctl status; for n in @DEFAULT_AUDIO_SINK@ @DEFAULT_AUDIO_SOURCE@; do echo \"== \$n\"; wpctl inspect \$n | grep -E 'node.name|node.description'; wpctl get-volume \$n; done" > "$O/wpctl.txt" 2>&1
JACK=$(grep -A3 -E "name='(Headphone|Headset) Jack'" "$O/amixer.txt" | grep -m1 -oE 'values=(on|off)' | cut -d= -f2)
echo "kernel $(sed -n 2p "$O/amixer.txt") | jack=${JACK:-unknown} | default sink: $(grep -A1 '== @DEFAULT_AUDIO_SINK@' "$O/wpctl.txt" | grep -oE 'node.name = .*' | cut -c13-) $(grep -A3 '== @DEFAULT_AUDIO_SINK@' "$O/wpctl.txt" | grep -m1 Volume)"
nodeid() { $DS "$ENV pw-dump 2>/dev/null" | python3 -c "
import json, sys
for o in json.load(sys.stdin):
    if ((o.get('info') or {}).get('props') or {}).get('node.name') == '$1': print(o['id'])"; }
V0=$($DS "$ENV wpctl get-volume @DEFAULT_AUDIO_SINK@" | awk '{print $2}')
HID=$(nodeid $HPS); HV0=""; [ -n "$HID" ] && HV0=$($DS "$ENV wpctl get-volume $HID" | awk '{print $2}')
restore() { $DS "$ENV wpctl set-volume @DEFAULT_AUDIO_SINK@ $V0; [ -n '$HID' ] && [ -n '$HV0' ] && wpctl set-volume $HID $HV0"; echo "volumes restored (default sink $V0, headphones ${HV0:-n/a})"; }
trap restore EXIT
$DS "$ENV wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.60; [ -n '$HID' ] && wpctl set-volume $HID 0.60; true"

# 2-4. speaker, from idle
sleep 25
sudo arecord -q -D hw:$NC,0 -f S24_3LE -c 2 -r 48000 -d 8 "$O/spk_ntg.wav" & R=$!
sleep 1
$DS "$ENV rm -f /var/tmp/snap_devmic.wav; timeout -s INT 7 pw-record --format s16 --rate 48000 --channels 1 /var/tmp/snap_devmic.wav & sleep 0.7; pw-play /var/tmp/snap1k.wav; wait" & P=$!
sleep 3.2; $RS 'sh /var/tmp/rp5-power/regsnap.sh' > "$O/regs_spk.txt" 2>&1
wait $P; wait $R; sudo chown "$(id -u)" "$O/spk_ntg.wav"
$RCP root@$H:/var/tmp/snap_devmic.wav "$O/spk_devmic.wav"
echo "speaker -> NTG:       $(python3 "$A/thd.py" "$O/spk_ntg.wav" 1000)"
echo "speaker -> RP5 mic:   $(python3 "$A/wavlevel.py" "$O/spk_devmic.wav" 1000)"
python3 "$T/regsnap-diff.py" "$O/regs_spk.txt" | sed 's/^/  regs: /'

# 5. jack
if [ "${JACK:-}" = on ] && [ -n "$UC" ] && [ -n "$HID" ]; then
  sleep 25
  sudo arecord -q -D hw:$UC,0 -f S16_LE -c 2 -r 48000 -d 7 "$O/hp_uca.wav" & R=$!
  sleep 1
  $DS "$ENV pw-play --target $HPS /var/tmp/snap1k.wav" & P=$!
  sleep 2.5; $RS 'sh /var/tmp/rp5-power/regsnap.sh' > "$O/regs_hp.txt" 2>&1
  wait $P; wait $R; sudo chown "$(id -u)" "$O/hp_uca.wav"
  echo "headphones -> UCA202: $(python3 "$A/thd.py" "$O/hp_uca.wav" 1000)"
  python3 "$T/regsnap-diff.py" "$O/regs_hp.txt" | sed 's/^/  regs: /'
else
  echo "jack test skipped (jack=${JACK:-unknown}, UCA202 card=${UC:-none}, headphones node=${HID:-none})"
fi
echo "files: $O"
