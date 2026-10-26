#!/bin/bash
# Apply the vendor (Qualcomm wcd939x-i2c.c) HSJ_CONNECT sequence + probe one-offs
# to the WCD9395 USBSS at i2c-2 0x0e, via raw i2c. Page reg = 0x00.
set -e
B=2; A=0x0e
pg(){ i2ctransfer -y $B w2@$A 0x00 $1; }
rd(){ i2ctransfer -y $B w1@$A $1 r1; }          # prints 0xNN
wr(){ i2ctransfer -y $B w2@$A $1 $2; }
rmw(){ # rmw <off> <clear-mask> <set-mask>
  local cur=$(rd $1); local new=$(( (cur & ~$2) | $3 ))
  wr $1 $(printf 0x%02x $new)
  echo "  reg $1: $cur -> $(printf 0x%02x $new)"
}
echo "== page 4: chip id + standby check"
pg 0x04
CHIP=$(rd 0x39); echo "CHIP_ID1(0x439)=$CHIP"
echo "== standby exit (USB_SS_CNTL bit4)"; rmw 0x19 0x10 0x00; sleep 0.02
echo "== page 0: probe one-offs (OVP/bias init vendor does at probe)"
pg 0x00
rmw 0x63 0x00 0x77        # FSM_OVERRIDE |= 0x77
rmw 0x1e 0x0e 0x08        # DP_EN OVP config
rmw 0x21 0x0e 0x08        # DN_EN
rmw 0x24 0x00 0x0c        # MG1_EN OVP-4V
rmw 0x28 0x00 0x0c        # MG2_EN OVP-4V
if [ "$CHIP" = "0x01" ]; then rmw 0x24 0x02 0x00; rmw 0x28 0x02 0x00; fi
rmw 0x20 0x00 0x09        # DP_DN_MISC1
rmw 0x27 0x00 0x24        # MG1_MISC
rmw 0x2b 0x00 0x24        # MG2_MISC
wr 0xa1 0xff              # surge sentinel
echo "== pd_pu_enable (THE MISSING DC-SENSE NETWORK)"
rmw 0x02 0x20 0x00        # PMP_OUT1 clear bit5
rmw 0x2c 0x20 0x00        # BIAS_TOP clear bit5 (D+/D- 1M & 400K PLDN)
rmw 0x1f 0x00 0x01        # DP_BIAS 2K PLDN
rmw 0x22 0x00 0x01        # DN_BIAS 2K PLDN
rmw 0x25 0x00 0x01        # MG1_BIAS SBU1 2K PLDN  <-- MBHC sense path
rmw 0x29 0x00 0x01        # MG2_BIAS SBU2 2K PLDN  <--
echo "== HSJ connect (page 0 part)"
rmw 0x25 0x08 0x00        # MG1_BIAS clear PCOMP_DYN_BST_EN
wr 0x43 0x00              # EXT_SW_CTRL_1
wr 0x3d 0xc4              # EXT_LIN_EN
wr 0x50 0x01              # SW_LIN_CTRL_1
wr 0x91 0x3c              # DC_TRIMCODE_2
wr 0x92 0x0f              # DC_TRIMCODE_3
wr 0x01 0x0f              # PMP_EN
if [ "$CHIP" = "0x01" ]; then rmw 0x02 0x00 0x40; fi   # HSJ_PWR_EN (v2.0 only)
echo "== HSJ connect (page 4 part)"
pg 0x04
rmw 0x19 0x07 0x01        # USB_SS_CNTL mode=1 (MBHC mode)
rmw 0x04 0x03 0x01        # SELECT0: MIC->MG2, SENSE->GSBU1
rmw 0x05 0x01 0x00        # SELECT1: AGND->MG1
rmw 0x03 0x07 0x07        # ENABLE: SENSE|MIC|AGND
echo "== final page-4 state:"
for r in 0x03 0x04 0x05 0x19; do echo "  0x4${r#0x}=$(rd $r)"; done
# leave chip on page 4 = kernel regmap's most likely cached selector
echo POKE_DONE
