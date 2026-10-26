#!/usr/bin/env bash
# run-acd-bench.sh — Pin each Adreno 830 OPP frequency and measure FP32 GFLOPS + GFLOPS/MHz
set -euo pipefail

DEVFREQ="/sys/class/devfreq/3d00000.gpu"
if [ ! -d "$DEVFREQ" ]; then
    DEVFREQ=$(ls -d /sys/class/devfreq/*gpu* | head -n1)
fi

ORIG_MIN=$(cat "$DEVFREQ/min_freq")
ORIG_MAX=$(cat "$DEVFREQ/max_freq")
ORIG_GOV=$(cat "$DEVFREQ/governor")

cleanup() {
    echo "$ORIG_GOV" > "$DEVFREQ/governor" 2>/dev/null || true
    echo "$ORIG_MIN" > "$DEVFREQ/min_freq" 2>/dev/null || true
    echo "$ORIG_MAX" > "$DEVFREQ/max_freq" 2>/dev/null || true
    echo "$ORIG_MIN" > "$DEVFREQ/min_freq" 2>/dev/null || true
}
trap cleanup EXIT

gcc -O2 /tmp/a830-acd-bench.c -o /tmp/a830-acd-bench -lEGL -lGLESv2

echo "=== Adreno 830 OPP Sweep ($(uname -r)) ==="
printf "%-10s %-10s %-12s %-12s %-10s\n" "TargetMHz" "ActualMHz" "GFLOPS" "GFLOPS/MHz" "Temp(mC)"

for f in $(cat "$DEVFREQ/available_frequencies"); do
    cur_max=$(cat "$DEVFREQ/max_freq")
    if [ "$f" -gt "$cur_max" ]; then
        echo "$f" > "$DEVFREQ/max_freq"
        echo "$f" > "$DEVFREQ/min_freq"
    else
        echo "$f" > "$DEVFREQ/min_freq"
        echo "$f" > "$DEVFREQ/max_freq"
    fi
    sleep 0.15
    out=$(/tmp/a830-acd-bench 8 2048)
    cur=$(cat "$DEVFREQ/cur_freq")
    temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -nr | head -n1 || echo 0)
    gflops=$(echo "$out" | sed -n 's/.*GFLOPS=\([0-9.]*\).*/\1/p')
    mhz=$((f / 1000000))
    cur_mhz=$((cur / 1000000))
    ratio=$(awk -v g="$gflops" -v m="$mhz" 'BEGIN { printf "%.3f", g / m }')
    printf "%-10s %-10s %-12s %-12s %-10s\n" "$mhz" "$cur_mhz" "$gflops" "$ratio" "$temp"
done
