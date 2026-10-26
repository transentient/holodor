#!/bin/bash
# pon-reason.sh — read and decode the Qualcomm PMIC power-on / power-off / fault reason registers
# (PON GEN2 peripheral, PM8150 at SPMI SID 0, base 0x0800) through regmap debugfs.
#
# Why: when the RP5 dies with nothing in the journal (2026-10-10, twice ~60 min into docked use),
# the PMIC still knows WHY it last powered off: PS_HOLD (software asked), UVLO (supply collapsed),
# OTST3 (PMIC over-temperature), PMIC watchdog, stage-3 key reset, a fault... The PON peripheral
# latches these in its always-on domain, so they survive the power-off and are readable on the
# next boot, before anything else is done. No serial console, no kernel change: the SPMI PMIC
# regmap is exported at /sys/kernel/debug/regmap/<bus>-<sid>/registers ("%04x: %02x\n" per
# register, 9 bytes each, seekable), so `dd bs=9 skip=<addr> count=1` reads one register.
#
# Runs ON the device as root:  systemd-run --wait --pipe --collect -q bash /tmp/pon-reason.sh
# Decode tables = downstream qpnp-power-on.c (GEN2). Offsets from the PON base:
#   0x05 SUBTYPE (0x04 = GEN2 primary)   0x08 PON_REASON1        0x0A/0x0B WARM_RESET_REASON1/2
#   0x0C/0x0D POFF_REASON1/2             0x0E/0x0F SOFT_RESET_REASON1/2
#   0x5A PS_HOLD_RST_CTL (what a PS_HOLD drop does NOW: bit7 enable, low nibble 1 warm/4 shutdown/7 hard)
#   0xC7 OFF_REASON (bit7 POFF_SEQ, bit6 FAULT_SEQ, bit5 S3_RESET_SEQ = which block explains the last off)
#   0xC8/0xC9 FAULT_REASON1/2            0xCA S3_RESET_REASON
set -u
LOG=/var/lib/pocknix/pon-reason.log
RM=/sys/kernel/debug/regmap

rd() { # rd <regmap-dir> <addr>  -> hex byte, or ?? on failure
  # line length ("%0Nx: %02x\n") depends on the map's address width: measure it from line 1
  local f="$1/registers" a=$2 line len
  len=$(head -c 64 "$f" 2>/dev/null | head -n1 | wc -c); [ "${len:-0}" -ge 6 ] || { echo "??"; return 1; }
  line=$(dd if="$f" bs="$len" skip="$a" count=1 2>/dev/null)
  [[ "${line%%:*}" == "$(printf '%0*x' $((len-5)) "$a")" ]] || { echo "??"; return 1; }
  echo "${line#*: }"
}
bits() { # bits <hex> <name0> <name1> ... -> names of set bits (or "none")
  local v=$((16#$1)) i=0 out=""; shift
  for n in "$@"; do (( v & (1<<i) )) && out+="${n} "; i=$((i+1)); done
  echo "${out:-none}"
}

PON_REASON=(HARD_RESET SMPL RTC DC_CHG USB_CHG PON1 CBLPWR KPDPWR)
POFF_REASON=(SOFT PS_HOLD PMIC_WD GP1 GP2 KPDPWR_AND_RESIN RESIN_N KPDPWR_N n/a n/a n/a CHARGER TFT UVLO OTST3 STAGE3)
FAULT_REASON=(GP_FAULT0 GP_FAULT1 GP_FAULT2 GP_FAULT3 MBG_FAULT OVLO UVLO AVDD_RB n/a n/a n/a FAULT_N PBS_WATCHDOG_TO PBS_NACK RESTART_PON OTST3)
S3_REASON=(n/a n/a n/a n/a FAULT_N PBS_WATCHDOG_TO PBS_NACK KPDPWR_ANDOR_RESIN)

dump_pon() { # dump_pon <sid-dir> <label>
  local d=$1 label=$2 base=$((0x800)) sub pr wr1 wr2 po1 po2 sr1 sr2 ctl off f1 f2 s3
  sub=$(rd "$d" $((base+0x05)))  || { echo "$label: no PON readable at $d"; return 1; }
  pr=$(rd "$d" $((base+0x08)));  wr1=$(rd "$d" $((base+0x0A))); wr2=$(rd "$d" $((base+0x0B)))
  po1=$(rd "$d" $((base+0x0C))); po2=$(rd "$d" $((base+0x0D)))
  sr1=$(rd "$d" $((base+0x0E))); sr2=$(rd "$d" $((base+0x0F)))
  ctl=$(rd "$d" $((base+0x5A)))
  off=$(rd "$d" $((base+0xC7))); f1=$(rd "$d" $((base+0xC8))); f2=$(rd "$d" $((base+0xC9))); s3=$(rd "$d" $((base+0xCA)))
  echo "== $label ($d) PON subtype 0x$sub"
  echo "raw: PON_REASON1=$pr WARM_RESET=$wr2$wr1 POFF=$po2$po1 SOFT_RESET=$sr2$sr1 OFF_REASON=$off FAULT=$f2$f1 S3=$s3 PS_HOLD_RST_CTL=$ctl"
  echo "power-on  : $(bits "$pr" "${PON_REASON[@]}")"
  echo "warm reset: $(bits "$wr2$wr1" "${POFF_REASON[@]}")"
  echo "power-off : $(bits "$po2$po1" "${POFF_REASON[@]}")"
  echo "soft reset: $(bits "$sr2$sr1" "${POFF_REASON[@]}")"
  echo "fault     : $(bits "$f2$f1" "${FAULT_REASON[@]}")"
  echo "s3 reset  : $(bits "$s3" "${S3_REASON[@]}")"
  local seq=$((16#$off)) which="unknown"
  (( seq & 0x80 )) && which="POFF block (normal power-off path: PS_HOLD/UVLO/OTST3/...)"
  (( seq & 0x40 )) && which="FAULT block (PMIC fault shutdown)"
  (( seq & 0x20 )) && which="S3_RESET block (stage-3 key/PBS reset)"
  echo "last off explained by: $which (OFF_REASON=0x$off)"
  local t=$((16#$ctl & 0x0f)) tn; case $t in 1) tn=warm-reset;; 4) tn=shutdown;; 7) tn=hard-reset;; *) tn="type $t";; esac
  local en=DISABLED; (( 16#$ctl & 0x80 )) && en=enabled
  echo "PS_HOLD drop now does: $tn ($en)"
}

main() {
  [ -d "$RM" ] || { echo "no $RM (debugfs not mounted or CONFIG_DEBUG_FS off)"; exit 1; }
  echo "pon-reason $(date '+%F %T') boot=$(cat /proc/sys/kernel/random/boot_id) uptime=$(cut -d' ' -f1 /proc/uptime)s"
  echo "regmaps: $(ls "$RM" | tr '\n' ' ')"
  local found=0
  for sid in 0-00 0-02 0-04; do
    [ -d "$RM/$sid" ] || continue
    case $sid in 0-00) l="PM8150 (SID0, system PON)";; 0-02) l="PM8150B (SID2)";; 0-04) l="PM8150L (SID4)";; esac
    dump_pon "$RM/$sid" "$l" && found=1
    echo
  done
  [ $found = 1 ] || echo "no PMIC regmap found under $RM"
}
mkdir -p "$(dirname "$LOG")"
main 2>&1 | tee -a "$LOG"
