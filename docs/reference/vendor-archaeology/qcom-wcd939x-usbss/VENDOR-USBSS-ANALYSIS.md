# Vendor wcd_usbss_i2c.ko (WCD9395 USBSS) — reverse-engineered register programming

Source: `ko/wcd_usbss_i2c.ko` from the AYN Odin 3 (SM8750) vendor_dlkm, disassembled with
`aarch64-linux-gnu-objdump -dr` (see `usbss-full.asm`). All register addresses below are the
flat paged-regmap addresses used by the mainline driver (`0x4xx` = page 4). "ub(reg, mask, val)"
= `regmap_update_bits`, "wr(reg, val)" = `regmap_write`.

**CONFIRMED against real vendor C source** (see §8): the module is built from Qualcomm's
`drivers/soc/qcom/wcd939x-i2c.c` + `wcd-usbss-utils.c` (msm-6.6, © 2022-2024 QuIC). The
matching sources are saved next to this file (`wcd-usbss-i2c.c`, `wcd-usbss.h`,
`wcd-usbss-priv.h`, `wcd-usbss-registers.h`, `oneplus-sm8750/`, `stock-sm8650/`). The asm
decode below matched the C line-for-line; register names have been filled in from
`wcd-usbss-registers.h` (`WCD_USBSS_BASE = -1`, so `OVP_BASE`=0x1e, etc.):

- 0x01 PMP_EN, 0x02 PMP_OUT1, 0x04 PMP_CLK (charge pump)
- 0x1e DP_EN, 0x1f DP_BIAS, 0x20 DP_DN_MISC1, 0x21 DN_EN, 0x22 DN_BIAS
- 0x24 MG1_EN, 0x25 MG1_BIAS, 0x27 MG1_MISC, 0x28 MG2_EN, 0x29 MG2_BIAS, 0x2b MG2_MISC
- 0x2c BIAS_TOP, 0x3d EXT_LIN_EN, 0x43 EXT_SW_CTRL_1, 0x50 SW_LIN_CTRL_1
- 0x63 FSM_OVERRIDE, 0x91 DC_TRIMCODE_2, 0x92 DC_TRIMCODE_3, 0x439 CHIP_ID1
- 0x469/0x46b SW_TAP_GND_L_LSB / SW_TAP_GND_R_LSB

Struct-offset key (ctxt = `wcd_usbss_ctxt_`, devm-alloc'd 0xdc0 bytes):
- `+432` = `cable_status` bitmask (bit N = cable type N connected). Audio mask = `0xb8` (bits 3,4,5,7).
- `+436` = surge enable (default 1), `+448` = surge kthread, `+456` = surge period ms (default 15000)
- `+464` = "standby feature enabled" (set when SDAM registration succeeds; also forced by sysfs `standby_mode` store)
- `+465` = "currently in standby" flag
- `+568` = **chip revision**, read from register `0x439` at probe
- `+572` = last applied SDAM usb_mode state, `+584` = nvmem cell, `+592/593/596` = suspended/deferred-event/event
- `+576` = runtime-PM refcount, `+600` = DT flag **`wcd-usb-sbu-compliance`** present
- `.bss+8` = global `audio_fsm_mode` (1 while AATC connected)

Every exported entry point brackets its work with `acquire_runtime_env()` (pm_stay_awake +
pm_runtime_resume_and_get, refcounted) / `release_runtime_env()`.

---

## 1. wcd_usbss_switch_update(ctype, connect_status) — 0x114c

`connect_status`: 1 = CONNECT, else DISCONNECT (0). Two jump tables over ctype 0..7.

### Cable-type enum mapping (from jump tables at .rodata+0xf58 / +0xf68)

Branch behaviour matches the Qualcomm downstream `enum wcd_usbss_cable_types` exactly.
**Confirmed** against `include/linux/soc/qcom/wcd939x-i2c.h`:
`WCD_USBSS_USB=0, DP_AUX_CC1=1, DP_AUX_CC2=2, AATC=3, GND_MIC_SWAP_AATC=4, HSJ_CONNECT=5,
CHARGER=6, GND_MIC_SWAP_HSJ=7`; `WCD_USBSS_CABLE_DISCONNECT=0, WCD_USBSS_CABLE_CONNECT=1`.

| val | enum                        | connect target | disconnect target |
|-----|-----------------------------|----------------|-------------------|
| 0   | WCD_USBSS_USB               | 0x1744         | 0x14d0            |
| 1   | WCD_USBSS_DP_AUX_CC1        | 0x13c0         | 0x11f4            |
| 2   | WCD_USBSS_DP_AUX_CC2        | 0x13c0         | 0x11f4            |
| 3   | WCD_USBSS_AATC              | 0x1754         | teardown (also clears bit4) |
| 4   | WCD_USBSS_GND_MIC_SWAP_AATC | 0x1e90         | teardown (also clears bit3) |
| 5   | WCD_USBSS_HSJ_CONNECT       | 0x1b70         | teardown (also clears bit7) |
| 6   | WCD_USBSS_CHARGER           | 0x1c98         | (nothing)         |
| 7   | WCD_USBSS_GND_MIC_SWAP_HSJ  | 0x1cf4         | teardown (also clears bit5) |

### CONNECT — common prologue (runs for EVERY cable type, before the switch)

C: `wcd_usbss_pd_pu_enable()` + `wcd_usbss_standby_control_locked(false)`:

```
cable_status |= BIT(ctype)
ub(0x02, 0x20, 0x00)          # PMP_OUT1 bit5 -> 0
ub(0x2c, 0x20, 0x00)          # BIAS_TOP bit5 -> 0  "Enable D+/D- 1M & 400K PLDN"
ub(0x1f, 0x01, 0x01)          # DP_BIAS bit0 -> 1   "Enable DP/DN 2K PLDN"
ub(0x22, 0x01, 0x01)          # DN_BIAS bit0 -> 1
if (!wcd-usb-sbu-compliance):         # ctxt+600 == 0
    ub(0x25, 0x01, 0x01)      # MG1_BIAS bit0 -> 1  "Enable SBU1/2 2K PLDN"
    ub(0x29, 0x01, 0x01)      # MG2_BIAS bit0 -> 1
if (in_standby):                      # ctxt+465
    ub(0x419, 0x10, 0x00)     # EXIT STANDBY (USB_SS_CNTL bit4 -> 0)
    usleep_range(10000, 10100)        # "10ms wait recommended to get WCD USBSS out of standby"
    in_standby = 0
```

So the prologue is pull-down/bias plumbing: 1M/400K pulldowns on D+/D-, 2K pulldowns on
DP/DN and on SBU1/SBU2 (the MG lines the headset ground/mic detection flows through).

### CONNECT per type

**USB (0)** → `wcd_usbss_dpdm_switch_update(true, true)`:
`ub(0x403, 0x18, 0x18)` (DNL+DPR switches on) then `ub(0x415, 0x80, 0x80)` (EQ_EN on).

**DP_AUX_CC1 (1) / CC2 (2)**:
```
ub(0x81, 0x07, 0x01)          # DISP_AUXP_CTL: LK_CANCEL_TRK_COEFF = 1
ub(0x80, 0xe0, 0xe0)          # DISP_AUXP_THRESH: OVPON_CM = max
ub(0x403, 0x60, 0x00)         # AUXP/AUXM->MGx switches off
ub(0x404, 0xc0, CC1 ? 0x40 : 0x80)   # AUXP/AUXM select MG1 (CC1) or MG2 (CC2)
ub(0x403, 0x60, 0x60)         # AUXP/AUXM switches on
regmap_read(0x407) ; verify (status & 0xcc) == (CC1 ? 0x48 : 0x84), else -EINVAL
```

**AATC (3)** (USB-C analog headset, uses the audio FSM):
```
ub(0x419, 0x07, 0x01)         # MODE = 1  (NB: vendor uses 1, not 2, for AATC too)
wr(0x01, 0x0f)                # PMP_OUT = 0x0f
wr(0x43, 0x00); wr(0x3d, 0xc4); wr(0x50, 0x01); wr(0x91, 0x3c); wr(0x92, 0x0f)
if (chip_rev == 1): ub(0x02, 0x40, 0x40)      # PMP_OUT1 HSJ_PWR_EN, rev-1 only
ub(0x403, 0x7f, 0x00)         # all switches off
audio_fsm_mode = 1
ub(0x433, 0x01, 0x01)         # AUDIO_FSM_START trigger (async)
ub(0x404, 0x3f, 0x02)         # SENSE->SBU2(GSBU2), MIC->MG1, DNL/DPR sel = 0
ub(0x29, 0x08, 0x00)          # MG2_BIAS PCOMP_DYN_BST_EN off
ub(0x403, 0x06, 0x06)         # MIC + SENSE switches on
ub(0x405, 0x01, 0x01)         # AGND -> MG2
ub(0x403, 0x01, 0x01)         # AGND switch on
ub(0x403, 0x18, 0x18)         # DNL/DPR on (select=0 -> route codec L/R onto D-/D+)
ub(0x411, 0xff, 0x02)         # DELAY_L_SW = 2
ub(0x40d, 0xff, 0x02)         # DELAY_R_SW = 2
ub(0x40e, 0xff, 0x01)         # DELAY_MIC_SW = 1
ub(0x433, 0x01, 0x01)         # FSM trigger again
ub(0x480, 0xff, 0x39); ub(0x48d, 0xff, 0x39)  # linearizer AUD_LEFT/RIGHT coef
ub(0x494, 0xff, 0xe8); ub(0x498, 0xff, 0x73)
ub(0x4a1, 0xff, 0xe8); ub(0x4a5, 0xff, 0x73)
ub(0x461, 0xff, 0x00); ub(0x463, 0xff, 0x00)  # RATIO_SPKR_REXT L/R LSB = 0
ub(0x419, 0x08, 0x00); ub(0x419, 0x08, 0x08)  # RCO_EN toggle 0 -> 1
usleep_range(10000, 10100)
```

**GND_MIC_SWAP_AATC (4)** (delta on top of AATC; prints "GND MIC Swap register updates.."):
```
ub(0x419, 0x07, 0x01) ; wr(0x01, 0x0f)
if (chip_rev == 1): ub(0x02, 0x40, 0x40)
ub(0x403, 0x02, 0x00)         # MIC switch off
ub(0x25, 0x08, 0x00)          # MG1_BIAS PCOMP_DYN_BST_EN off
ub(0x405, 0x01, 0x00)         # AGND -> MG1
ub(0x404, 0x3f, 0x01)         # MIC -> MG2, SENSE -> SBU1
ub(0x403, 0x02, 0x02)         # MIC switch on
```

**HSJ_CONNECT (5)** — **the dedicated 3.5 mm jack path** (no FSM, no DNL/DPR change).
Comments below are verbatim from the vendor C:
```
ub(0x419, 0x07, 0x01)         # "Update power mode to mode 1" (MBHC-capable audio mode)
wr(0x01, 0x0f)                # PMP_EN = 0xF        (charge pump on)
wr(0x43, 0x00)                # EXT_SW_CTRL_1
wr(0x3d, 0xc4)                # EXT_LIN_EN
wr(0x50, 0x01)                # SW_LIN_CTRL_1
wr(0x91, 0x3c)                # DC_TRIMCODE_2
wr(0x92, 0x0f)                # DC_TRIMCODE_3
if (version == WCD_USBSS_2_0): ub(0x02, 0x40, 0x40)  # PMP_OUT1 HSJ_PWR_EN (2.0 silicon only;
                                                     #  CHIP_ID1(0x439)==1 => "Harmonium 2.0")
ub(0x404, 0x03, 0x01)         # "Select MG2, GSBU1": MIC -> MG2, SENSE -> GSBU1 (bits5:2 untouched)
ub(0x405, 0x01, 0x00)         # AGND -> MG1
ub(0x25, 0x08, 0x00)          # "Disable OVP_MG1_BIAS PCOMP_DYN_BST_EN"
ub(0x403, 0x07, 0x07)         # "Enable SENSE, MIC, AGND switches" (DNL/DPR/AUX bits untouched)
```

**CHARGER (6)**:
```
ub(0x403, 0x18, 0x00)         # DNL/DPR off
ub(0x404, 0x3c, 0x28)         # DNL sel = DN2, DPR sel = DR2 (secondary/charger path)
ub(0x403, 0x18, 0x18)         # DNL/DPR on
```

**GND_MIC_SWAP_HSJ (7)**:
```
ub(0x403, 0x07, 0x00)         # sense/mic/agnd off
ub(0x404, 0x03, 0x02)         # MIC -> MG1, SENSE -> SBU2
ub(0x405, 0x01, 0x01)         # AGND -> MG2
ub(0x403, 0x07, 0x07)         # back on
```

### CONNECT/teardown epilogue (all paths)
If after the operation `cable_status & 0xb8` (any audio type still connected) → ctxt+572 = 8
("AUDIO" SDAM state), so the SDAM handler won't repurpose the switch.

### DISCONNECT

Common: `cable_status &= ~BIT(ctype)`, then per type:

- **USB (0)**: if (standby enabled && in standby) `dpdm_switch_update(false,false)` else
  `dpdm_switch_update(true,false)` (leaves D+/D- switches closed, EQ off).
- **DP_AUX_CC1/CC2 (1,2)**: `ub(0x404, 0xc0, 0x00)`, `ub(0x403, 0x60, 0x00)`, and clears both
  bits 1,2 from cable_status.
- **AATC(3)/GND_MIC_SWAP_AATC(4)/HSJ(5)/GND_MIC_SWAP_HSJ(7)**: also clear the partner type's
  bit (3↔4, 5↔7); **if cable_status is now 0**, run the audio teardown:

```
ub(0x403, 0x07, 0x00)         # sense/mic/agnd off
ub(0x405, 0x01, 0x00)         # AGND -> MG1
ub(0x404, 0x03, 0x00)         # MIC -> MG1, SENSE -> GSBU1
ub(0x25, 0x08, 0x08)          # MG1_BIAS PCOMP_DYN_BST_EN back on
ub(0x29, 0x08, 0x08)         # MG2_BIAS PCOMP_DYN_BST_EN back on
ub(0x433, 0x01, 0x01)         # FSM trigger (async)
ub(0x404, 0x3c, 0x14)         # DNL sel = DN, DPR sel = DP  (restore USB data path)
ub(0x419, 0x07, 0x05)         # mode = USB (5)
wr(0x01, 0x00)                # PMP_OUT off
if (chip_rev == 1): ub(0x02, 0x40, 0x00)   # HSJ_PWR_EN off
wr(0x43, 0x00); wr(0x3d, 0x00); wr(0x04, 0x10); wr(0x50, 0x00); wr(0x91, 0x00); wr(0x92, 0x00)
audio_fsm_mode = 0
if (standby feature enabled):         # ctxt+464 (SDAM present)
    ub(0x403, 0x18, 0x00)     # DNL/DPR off
    if (!in_standby):
        ub(0x419, 0x10, 0x10) # ENTER STANDBY
        in_standby = 1
    ctxt+572 = 0 (STANDBY)
else:
    ub(0x403, 0x18, 0x18)     # keep DNL/DPR on
    ctxt+572 = 2 (USB)
```

---

## 2. wcd_usbss_set_switch_settings_enable(switch_type, status) — 0x9b8

Trivial: validates `switch_type <= 7`, `status <= 1`, then
`ub(0x403, 1 << switch_type, status << switch_type)`. (switch_type is the bit index in
SWITCH_SETTINGS_ENABLE: 0=AGND, 1=MIC, 2=SENSE, 3=DPR, 4=DNL, 5=AUXM, 6=AUXP, 7=DEVICE_ENABLE.)

## 2b. wcd_usbss_audio_config(enable, config_type, power_mode) — 0xf6c

Called by the codec driver on jack/stream events to switch the audio power mode.
- No-op unless `cable_status & 0xb8` (an audio cable-type must be "connected").
- `config_type` must be 0 (`WCD_USBSS_CONFIG_TYPE_POWER_MODE`), anything else → -EINVAL.
- Reads `0x419 & 7`; if already == power_mode, done. Otherwise (C source semantics):
  - **power_mode == 1** — "switching to MBHC mode": `wr(PMP_EN 0x01, 0x0f)`,
    `wr(EXT_LIN_EN 0x3d, 0xc4)`, `ub(0x419, 0x07, 0x01)`, `wr(PMP_CLK 0x04, 0x10)`
  - **any other mode** — forced to `HIFI_MODE4` (= 4): `wr(PMP_CLK 0x04, 0x10)`,
    `ub(0x419, 0x07, 0x04)`, `wr(PMP_EN 0x01, 0x00)`, `wr(EXT_LIN_EN 0x3d, 0x00)`
    (a true ULP mode 2 would use PMP_CLK 0x1c, but this build forces mode 4)
- The `enable` argument is ignored.
- Key implication: **mode 1 is the only mode in which MBHC works** — the charge pump and
  linearizer are on. HiFi mode 4 turns PMP_EN off.

## 2c. wcd_usbss_dpdm_switch_update(enable, eq_enable) — 0xe3c
`ub(0x403, 0x18, enable ? 0x18 : 0)` ; `ub(0x415, 0x80, eq_enable ? 0x80 : 0)`.

## 2d. wcd_usbss_update_default_trim() — 0x2154
`wr(0x50, 0x01); wr(0x90, 0x00); wr(0x91, 0x00); wr(0x92, 0x00)`.

## 2e. wcd_usbss_get_sbu_switch_orientation() — 0x690
Reads `0x404 & 3`: returns 1 if ==1 (MIC→MG2 i.e. "GSBU1 = ground"), 2 if ==2, else 0.

## 2f. wcd_usbss_linearizer_rdac_cal_code_select(src) — 0xa84
`ub(0x413, 0x04, src << 2)` (FUNCTION_ENABLE bit2). set_linearizer_sw_tap writes 0x465..0x46c.

---

## 3. FOCUS QUESTION A — dedicated 3.5 mm jack

The dedicated-jack path is **WCD_USBSS_HSJ_CONNECT = 5** (with GND_MIC_SWAP_HSJ = 7 as the
swap variant). The full effective vendor sequence for `switch_update(WCD_USBSS_HSJ_CONNECT,
CONNECT)` is *common prologue + HSJ branch*, i.e. in order:

1.  `0x02 &= ~0x20` (PMP_OUT1 bit5 clear)
2.  `0x2c &= ~0x20`
3.  `0x1f |= 0x01`
4.  `0x22 |= 0x01`
5.  `0x25 |= 0x01` (MG1_BIAS bit0) — unless DT `wcd-usb-sbu-compliance`
6.  `0x29 |= 0x01` (MG2_BIAS bit0) — unless DT `wcd-usb-sbu-compliance`
7.  if standby: `0x419 &= ~0x10`, **sleep 10 ms**
8.  `0x419` mode=1; `0x01=0x0f`; `0x43=0`; `0x3d=0xc4`; `0x50=0x01`; `0x91=0x3c`; `0x92=0x0f`
9.  `0x02 |= 0x40` (HSJ_PWR_EN) **only if chip rev (reg 0x439) == 1**
10. `0x404` mask 0x03 → 0x01 (MIC→MG2, SENSE→GSBU1; DNL/DPR selects NOT touched)
11. `0x405` mask 0x01 → 0 (AGND→MG1)
12. `0x25 &= ~0x08` (PCOMP_DYN_BST_EN off)
13. `0x403` mask 0x07 → 0x07 (AGND|MIC|SENSE on; DNL/DPR/AUX bits NOT touched)

### Diff vs our current Linux HSJ sequence

What we already match: `0x419` mode=1, `0x01=0x0f`, `0x43=0`, `0x3d=0xc4`, `0x50=0x01`,
`0x91=0x3c`, `0x92=0x0f`, MIC select bit0=1, AGND select=0, MG1_BIAS PCOMP_DYN_BST clear,
final 0x403 with SENSE|MIC|AGND set.

What the vendor does that we DON'T (most likely MBHC blockers, in suspicion order):

1. **Standby exit**: if `0x419` bit4 is set the switch is asleep; vendor always clears it and
   waits 10 ms *before* programming ("10ms wait recommended to get WCD USBSS out of
   standby"). If the Odin's boot state (or a prior SDAM state) left bit4 = 1, none of our
   programming reaches the analog core. Read 0x419 first.
2. **Pull-down/bias enables in the connect prologue** (`wcd_usbss_pd_pu_enable()`):
   `DP_BIAS 0x1f bit0=1`, `DN_BIAS 0x22 bit0=1`, **`MG1_BIAS 0x25 bit0=1`,
   `MG2_BIAS 0x29 bit0=1` ("Enable SBU1/2 2K PLDN")**, plus `PMP_OUT1 0x02 bit5=0`,
   `BIAS_TOP 0x2c bit5=0` ("Enable D+/D- 1M & 400K PLDN"). The 2K pulldowns on SBU1/SBU2
   (= MG1/MG2, the jack's ground & mic pins) give MBHC its DC detection path. Chip regmap
   defaults are 0x1f/0x22/0x25/0x29 = 0x0f (bit0 set), but the SDAM handler's LPD/
   LPD_CONTINUOUS states clear them — verify the live values.
3. **Probe-time one-off init we may be missing** (see Q.B below) — especially
   `MG1_EN 0x24 |= 0x0c` and `MG2_EN 0x28 |= 0x0c` (OVP 4V updates) and the
   update_reg_init writes `MG1_MISC 0x27 |= 0x24`, `MG2_MISC 0x2b |= 0x24` (MG OVP dynamic
   boosting), `DP_DN_MISC1 0x20 |= 0x09`, `CPLDO_CTL2 0xa1 = 0xff`.
4. Vendor sets 0x02 bit6 (HSJ_PWR_EN) **only when CHIP_ID1 (0x439) == 1 ("Harmonium 2.0"
   silicon)**, and on 2.0 also clears MG1_EN/MG2_EN bit1 at probe. We set bit6
   unconditionally — check what 0x439 reads on the Odin 3.
5. Vendor does **not** touch DNL/DPR selects (0x404 bits 5:2) or enables (0x403 bits 4:3) in
   the HSJ path — they stay in whatever state USB left them (selects = DN/DP = 0x14,
   enables on). We clear the selects to 0 (= route codec L/R to USB D∓ lines) — functionally
   dubious but probably not the MBHC blocker; still, match the vendor: leave them alone.
6. Vendor writes 0x403's low three bits in ONE update (mask 0x07 val 0x07) after selects are
   final; our observed end value 0x9f is consistent with theirs (bit7 DEVICE_ENABLE + 0x18
   left over from USB mode + 0x07).

Note also: register **0x408 is never touched** by the vendor driver, and the vendor "MG"
registers are page-0 0x24–0x30 (0x24 MG1_EN, 0x25 MG1_BIAS, 0x27 MG1_MISC, 0x28 MG2_EN,
0x29 MG2_BIAS, 0x2b MG2_MISC), NOT 0x414–0x418 (0x40d/0x40e/0x411 are switch-delay regs,
0x413 FUNCTION_ENABLE, 0x415 EQUALIZER1, 0x419 USB_SS_CNTL — matching mainline).

## 4. FOCUS QUESTION B — probe/init & disconnected/default state

### wcd_usbss_probe (0x2228), register-relevant part, in order

```
regulator "vdd-usb-cp" get+enable; optional pinctrl state "active" (reset pins)
regmap init (defaults table wcd_usbss_defaults; cache maintained)
if DT has "wcd-usb-sbu-compliance": ctxt+600=1; ub(0x25,0x01,0); ub(0x29,0x01,0)
                                  # "external zener installed, disable OVP + SBUx pulldowns"
ub(0x63, 0x77, 0x77)          # FSM_OVERRIDE: "OVP-Fuse settings recommended from HW"
ub(0x1e, 0x0e, 0x08)          # DP_EN OVP field
ub(0x21, 0x0e, 0x08)          # DN_EN OVP field
ub(0x81, 0x07, 0x01)          # DISP_AUXP_CTL LK_CANCEL_TRK_COEFF
ub(0x80, 0xe0, 0xe0)          # DISP_AUXP_THRESH  "Display common mode and OVP 4V updates"
ub(0x82, 0xe0, 0xe0)          # DISP_AUXM_THRESH
ub(0x24, 0x0c, 0x0c)          # MG1_EN bits3:2  <-- important for MG path
ub(0x28, 0x0c, 0x0c)          # MG2_EN bits3:2
read 0x439 (CHIP_ID1) -> version (1 = "Harmonium 2.0" = WCD_USBSS_2_0)
if version == 2.0: ub(0x24, 0x02, 0); ub(0x28, 0x02, 0)
wr(0x43, 0x00)                # EXT_SW_CTRL_1
wr(0x469, 0x00); wr(0x46b, 0x00)      # SW_TAP_GND_L_LSB / SW_TAP_GND_R_LSB
                              # "SET LINEARIZER TAP registers to default for THD+N"
wr(0x413, 0x05)               # FUNCTION_ENABLE: source=MANUAL(1) + bit2 (rdac cal code)
sdam registration:  ctxt+572=2 (USB); nvmem cell "usb_mode"; threaded IRQ "wcd-usbss-sdam"
                    (handler = wcd_usbss_sdam_notifier_handler), irq_set_irq_wake(1)
  -> on success: ctxt+464 = 1 (standby feature enabled)
register_ucsi_glink_notifier(wcd_usbss_usbc_event_changed)
wcd_usbss_update_reg_init():
    ub(0x413, 0x03, audio_fsm_mode ? 2 : 1)   # = 1 (MANUAL) at probe
    ub(0x20, 0x09, 0x09)      # DP_DN_MISC1: DP/DN PCOMP_2X_DYN_BST_ON_EN
    ub(0x27, 0x24, 0x24)      # MG1_MISC: PCOMP_2X_DYN_BST_ON_EN(bit5) + bit2
    ub(0x2b, 0x24, 0x24)      # MG2_MISC: same
    ub(0x415, 0x80, 0x00)     # EQ off
    ub(0xa1, 0xff, 0xff)      # CPLDO_CTL2 = 0xff
sysfs /sys/kernel/wcd_usbss/{surge_enable,surge_period,standby_mode}
surge: period=15 s, enabled, kthread started
```

Regmap defaults worth knowing (from `wcd_usbss_defaults`): `0x02=0x08`, `0x03=0x07`,
`0x04=0x10`, `0x1e=0x04`, `0x1f=0x0f`, `0x21=0x04`, `0x22=0x0f`, `0x23=0x34`, `0x24=0x0a`,
`0x25=0x0f`, `0x26=0x21`, `0x28=0x0a`, `0x29=0x0f`, `0x2a=0x21`, `0x2c=0x00`, `0x2d=0x40`,
`0x2e=0x20`, `0x2f=0x0f`, `0x45=0x00`, `0x63=0x40`, `0x80=0x60`, `0x81=0xc3`, `0x82=0xa0`,
`0x83=0xc3`, `0xa0=0x08`, `0xa1=0x00`.

### Disconnected/default state relevant to MBHC

- With no cable and standby feature enabled, the vendor idles the part in **STANDBY**
  (0x419 bit4=1) with DNL/DPR open — MBHC cannot see anything in that state; detection of
  a new insertion is done by the **PMIC SDAM**, which raises the SPMI interrupt and the
  driver then reprograms + exits standby. On a phone the USB-C jack insertion is detected
  by UCSI/PMIC, not by the WCD switch.
- For a *dedicated* HSJ design the expectation is that the machine driver calls
  `switch_update(WCD_USBSS_HSJ_CONNECT, CONNECT)` once (jack always "connected" at the
  switch level) and MBHC mech detection then runs continuously through
  SENSE(GSBU1)/MIC(MG2)/AGND(MG1) with MG bias on and standby never entered.
  So for Holodor: program the HSJ sequence once at codec init, make sure standby is off,
  and keep 0x25/0x29 bit0 + 0x24/0x28 bits3:2 + 0x27/0x2b bits set as above.

## 5. SDAM / nvmem "usb_mode" cell and interrupt handler

- Probe gets nvmem cell **"usb_mode"** and requests a threaded wake-capable IRQ named
  **"wcd-usbss-sdam"** → `wcd_usbss_sdam_notifier_handler` (0x2e7c).
- Handler: `nvmem_cell_read(usb_mode)`, `state = byte & 0x7`. If unchanged vs ctxt+572, just
  logs ("wcd already in %s mode", names: 0=STANDBY 1=LPD 2=USB 3=LPD_USB 4/6=UNDEFINED
  5/7=LPD_CONTINUOUS 8=AUDIO). If system is suspending (ctxt+592), defers the event to
  pm_resume; otherwise `wcd_usbss_sdam_handle_events_locked(state)` (0x3000):

  - **STANDBY (0)**: `0x02 &= ~0x20; 0x2c &= ~0x20; 0x1f |= 1; 0x22 |= 1;`
    (+`0x25|=1; 0x29|=1` unless compliance) — comparators ON so the PMIC can watch the pins —
    then `0x403 &= ~0x18` (D+/D- open), `0x415 &= ~0x80`, and `0x419 |= 0x10` (enter standby).
  - **LPD (1) / LPD_USB (3)** (liquid detection): `0x02 |= 0x20; 0x1f &= ~1; 0x22 &= ~1;
    0x2c |= 0x20;` (+`0x25 &= ~1; 0x29 &= ~1` unless compliance); `0x403 |= 0x18`;
    exit standby + 10 ms if needed.
  - **USB (2)**: `0x02 &= ~0x20; 0x2c &= ~0x20; 0x1f |= 1; 0x22 |= 1;` (+`0x25|=1; 0x29|=1`);
    `0x403 |= 0x18`; exit standby + 10 ms.
  - **LPD_CONTINUOUS (5,7)**: `0x02 |= 0x20`; `0x25 &= ~1; 0x29 &= ~1`; `0x403 |= 0x18`;
    exit standby.
  - AUDIO (8) never arrives via SDAM table (handler only switches 0..7; 8 is set locally
    by switch_update when audio is connected, and handle_events is skipped for it).
- `pm_suspend` just marks ctxt+592; `pm_resume` replays a deferred SDAM event.
- sysfs `standby_mode` store: 0 → exit standby (+10 ms); nonzero → enter standby only if
  `cable_status == 0`; also re-arms ctxt+464.

## 6. Surge protection kthread (0x3764)

Every `surge_period` (15 s), if not in standby: read `0xa1` — must be 0xff ("Surge check #1");
read `0x15` bit1 ("check #2"), re-read up to 10× ("check #3"). On failure:
`regcache_mark_dirty + regcache_sync` (full register restore!), `0xa1 = 0xff`,
`0x419` RCO_EN toggle 0→1, and if audio was connected, notify the codec chain with event 3
(so MBHC re-detects). If in standby: instead pulses `0x05` bit0 0→1→0 and reads `0x06`.

## 7. UCSI glink notifier

`wcd_usbss_usbc_event_changed` caches the new mode (only 0/1 accepted), queues
`wcd_usbss_usbc_analog_work_fn`, which fires the driver's own blocking notifier chain
(the downstream wcd939x codec driver listens and then calls back into
`wcd_usbss_switch_update` with AATC etc.). Event 1 passes `&noti_flag` where flag=1 if audio
already connected. No direct register writes from this path.

## 8. Cross-check against public source — CONFIRMED

The real vendor C source was found and diffed against the asm; they match on every register
write, including the msm-6.6-specific fingerprint (EXT_SW_CTRL_1=0x00, EXT_LIN_EN=0xC4,
SW_LIN_CTRL_1=0x01, DC_TRIMCODE_2/3=0x3C/0x0F in the AATC/HSJ connect paths — the older
msm-6.1 build wrote EXT_SW_CTRL_1=0x9E, EXT_LIN_EN=0x02 and no trimcodes).

- Real filename: `drivers/soc/qcom/wcd939x-i2c.c` (+ `wcd-usbss-utils.c`,
  `wcd-usbss-regmap.c`, `wcd-usbss-tables.c`); public header
  `include/linux/soc/qcom/wcd939x-i2c.h`; private `drivers/soc/qcom/wcd-usbss-priv.h`.
- Matching stock msm-6.6 source (© 2022-2024 QuIC, sm8735/sm8750 era), saved locally as
  `wcd-usbss-i2c.c` etc. in this directory. Origin:
  https://github.com/NothingOSS/android_kernel_msm-6.6_nothing_sm8735 (branch sm8735/v/mr).
- Actual SM8750 OEM tree (OnePlus 13, adds OPLUS charger-disconnect case + surge workqueue):
  https://github.com/OnePlusOSS/android_kernel_oneplus_sm8750 → saved in `oneplus-sm8750/`.
- Older msm-6.1 (sm8650) variant for comparison in `stock-sm8650/`.
- The `enable_standby`/naming details above (`pd_pu_enable`, `standby_control_locked`,
  `switch_update_defaults`, `WCD_USBSS_2_0`) are the C names for the asm blocks decoded in
  §1–§7; struct offsets map: +432 cable_status, +464 standby_enable, +465 is_in_standby,
  +568 version, +572 wcd_standby_status, +600 usb_sbu_compliance.
