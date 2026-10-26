#!/bin/sh
# k48-audio-checks.sh (2026-10-16): after installing kernel 48 (upstream LPASS PM-clock backports + TX SoundWire wake irq).
# Run as root on the device. Quiet only: the playback test is a -40 dBFS tone at the default slider (no loud tests).
c() { cat /sys/kernel/debug/clk/$1/clk_prepare_count 2>/dev/null; }
votes() { printf "HW_MACRO=%s HW_DCODEC=%s TX_MCLK=%s NPL=%s" "$(c LPASS_HW_MACRO)" "$(c LPASS_HW_DCODEC)" "$(c LPASS_CLK_ID_TX_CORE_MCLK)" "$(c LPASS_CLK_ID_TX_CORE_NPL_MCLK)"; }
adsp() { awk '/Count/{print $2}' /sys/kernel/debug/qcom_stats/adsp; }
st() { for d in 3200000.rxmacro 3220000.txmacro 3370000.codec 3240000.codec 33c0000.pinctrl; do printf "%s=%s " $d "$(cat /sys/bus/platform/devices/$d/power/runtime_status)"; done; }
echo "kernel=$(pacman -Q linux-pocknix-sm8250 | cut -d' ' -f2) card=$(ls /proc/asound | grep -c RetroidPocket) deferred=$(wc -l < /sys/kernel/debug/devices_deferred)"
echo "swr wake irq: $(grep -E 'swr_wake_irq' /proc/interrupts | awk '{print $1, $NF}' | tr '\n' ' ')"
echo "macro/pinctrl runtime PM: $(st)"
echo "[1] as shipped (nosleep rule control=on): $(votes) adsp_sleeps=$(adsp)"
for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo auto > $s/power/control; done
sleep 8
echo "[2] rule lifted 8 s: $(votes) adsp_sleeps=$(adsp) | $(st)"
sleep 20
echo "[3] +20 s idle: $(votes) adsp_sleeps=$(adsp)  ($(tr '\n' ' ' < /sys/kernel/debug/qcom_stats/adsp))"
python3 - <<'PY'
import math, struct, wave
fs = 48000; a = 10 ** (-40 / 20) * 32767
w = wave.open("/var/tmp/quiet1k.wav", "wb"); w.setnchannels(2); w.setsampwidth(2); w.setframerate(fs)
w.writeframes(b"".join(struct.pack("<hh", int(a * math.sin(2 * math.pi * 1000 * i / fs)), int(a * math.sin(2 * math.pi * 1000 * i / fs))) for i in range(fs * 2)))
PY
U=deck; R=/run/user/$(id -u $U)
su $U -c "XDG_RUNTIME_DIR=$R timeout 6 pw-play /var/tmp/quiet1k.wav" & P=$!
sleep 1; echo "[4] during a -40 dBFS speaker tone: pcm1p=$(head -1 /proc/asound/card0/pcm1p/sub0/status 2>/dev/null) $(votes)"
wait $P; echo "    pw-play exit=$?"
sleep 8
echo "[5] 8 s after playback: $(votes) | $(st)"
echo "dmesg (audio errors since boot): $(dmesg | grep -ciE 'q6afe.*(err|fail)|q6asm.*(err|fail)|lpass.*(err|fail)|macro.*(err|fail)|soundwire.*(err|fail)|swr.*(err|fail)')"; dmesg | grep -iE 'q6afe.*(err|fail)|lpass.*(err|fail)|macro.*(err|fail)|soundwire.*(err|fail)|swr.*(err|fail)' | tail -4 | cut -c1-140
for s in /sys/bus/soundwire/devices/sdw:*:0217:010d:*; do echo on > $s/power/control; done; echo "nosleep rule restored (control=on)"
