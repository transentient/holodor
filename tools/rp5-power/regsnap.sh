#!/bin/sh
# regsnap.sh (2026-10-16), run as root ON THE RP5: LPASS macro registers, cache AND hardware readback, per macro.
# Purpose: kernel 48 lets the macros drop their LPASS core votes when idle, so their registers can be lost and must be
# restored by regcache_sync on the next resume. Cache == hardware (for every cached register) during playback = the
# restore worked. Compare the hardware blocks across kernels with regsnap-diff.py.
# Safety: hardware is read only while the macro is runtime-active. A suspended macro is cache_only and a bypassed
# read returns EBUSY without touching it (drivers/base/regmap/regmap.c _regmap_read). Writes made while cache_bypass=Y
# skip the cache, so the bypass window is one 'cat' per macro, mid-tone (no DAPM changes then).
# cache_bypass=Y taints the kernel (TAINT_USER) until the next reboot.
for d in /sys/kernel/debug/regmap/*; do
  n=${d##*/}
  case $n in 3200000.rxmacro*|3220000.txmacro*|3240000.codec*|3370000.codec*) ;; *) continue ;; esac
  st=$(cat /sys/bus/platform/devices/${n%%-*}/power/runtime_status 2>/dev/null)
  echo "== $n runtime=$st"
  echo "-- cache"; cat $d/registers
  [ "$st" = active ] || continue
  echo "-- hw"; echo Y > $d/cache_bypass; cat $d/registers; echo N > $d/cache_bypass
done
