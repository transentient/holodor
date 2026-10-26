#!/bin/bash
# EDL factory restore of the Odin 3 from fusor with the bkerler edl client (Firehose).
#   ~/edl-flash.sh check   -> Sahara handshake + print the current GPT (READ-ONLY)
#   ~/edl-flash.sh flash   -> full AYN Odin3_20251206 restore: all 6 LUNs, rawprogram + patch
# Device must be in EDL (9008): off, USB to fusor, hold power + vol+ + vol- until lsusb shows 05c6:9008.
set -o pipefail
EDL=${EDL:-$HOME/edlenv/bin/edl}   # bkerler/edl client (git clone https://github.com/bkerler/edl; python -m venv; pip install -r requirements.txt .; venv lived in the 09-11 session scratchpad)
IMG=/home/cliff/odin3-backups/edl-20251206/Odin3_20251206
LOADER=$IMG/xbl_s_devprg_ns.melf
LOG=/home/cliff/odin3-backups/edl-20251206/edl-$(date +%Y%m%d-%H%M%S)-$1.log
RAW=rawprogram_unsparse0.xml,rawprogram1.xml,rawprogram2.xml,rawprogram3.xml,rawprogram_unsparse4.xml,rawprogram5.xml
PATCH=patch0.xml,patch1.xml,patch2.xml,patch3.xml,patch4.xml,patch5.xml
[ -f "$LOADER" ] || { echo "loader missing: $LOADER"; exit 1; }
lsusb | grep -q "05c6:9008" || { echo "no Qualcomm 9008 device on USB (device not in EDL)"; exit 1; }
case "$1" in
  check)
    echo "=== EDL CHECK $(date +%T) (read-only)" | tee -a "$LOG"
    sudo "$EDL" printgpt --memory=ufs --loader="$LOADER" 2>&1 | tee -a "$LOG" ;;
  flash)
    echo "=== EDL FLASH $(date +%T) full Odin3_20251206 restore" | tee -a "$LOG"
    cd "$IMG" && sudo "$EDL" qfil "$RAW" "$PATCH" "$IMG" --memory=ufs --loader="$LOADER" 2>&1 | tee -a "$LOG"
    echo "=== EDL FLASH END $(date +%T) exit ${PIPESTATUS[0]}" | tee -a "$LOG" ;;
  *) echo "usage: $0 check|flash"; exit 2 ;;
esac
