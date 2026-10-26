#!/bin/sh
# bench.sh <tag> <secs> [press buttons...]: frames + sampler for <secs>, optional button presses every 7 s; prints summary
T=$1; S=$2; shift 2; R=deck@192.168.1.68; D=/var/tmp/spk
ssh $R "systemd-run --user --quiet --unit=claude-samp-$T --collect sh -c 'cd $D && exec sh rp5-sampler.sh > samp_$T.txt 2>/dev/null'"
if [ $# -gt 0 ]; then (n=$(( S / 7 )); for i in $(seq 1 $n); do sleep 7; sh ~/rp5-vs-hang/bin/rp5pad.sh "$@" >/dev/null 2>&1; done) & fi
ssh $R "cd $D && python3 gsframes.py $T.csv $S >/dev/null 2>&1; python3 gsstats.py $T.csv; python3 vis.py $T.csv | tail -1"
wait
ssh $R "systemctl --user stop claude-samp-$T 2>/dev/null; awk -F'[ =]' '/main_cpu/{for(i=1;i<=NF;i++){if(\$i==\"main_cpu\")m+=\$(i+1); if(\$i==\"proc_cpu\")p+=\$(i+1); if(\$i==\"game_gpu\")g+=\$(i+1); if(\$i==\"gpu_Hz\")f+=\$(i+1); if(\$i==\"maxtemp\")t+=\$(i+1); if(\$i==\"shader_cpu\")s+=\$(i+1)} n++} END{if(n) printf \"sampler: game main thread %.0f%% of a core, whole process %.0f%%, shader threads %.0f%%, GPU busy %.0f%%, GPU %.0f MHz, max temp %.1f C (n=%d)\n\", m/n/10, p/n/10, s/n/10, g/n, f/n/1e6, t/n/1000, n}' $D/samp_$T.txt"
