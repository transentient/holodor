# Staged from batocera.pocket (darkplace/batocera.pocket, GPL-2.0) — 2026-08-08

NOT yet applied. All test-applied clean against our 7.1.3 + 40-holodor tree except 1300.
Credit: lukemotion / batocera.pocket (continuing suckbluefrog's work) — ROCKNIX-sibling
lineage, same patch family as ours.

Promotion plan (in order):
1. **0513 geni-mask-non-console-irq-on-suspend** — THE 0508-revival candidate: they ship
   0508 (rsinput MCU resume reinit) WITH this and suspend works; the rsinput MCU rides
   this serial engine. Experiment: promote 0513 + restore 0508 from patches-disabled/ ->
   build -> suspend soak. If clean: full suspend saga closure WITH resume-reinit back.
   If it wedges again: drop both, keep current state (suspend already works without 0508).
2. **0030 HTR3212 LED driver + DTS nodes from their 0047** (lines ~150-260: TWO
   controllers, right stick i2c_hub_3/tlmm 88, left i2c_hub_4/tlmm 87, 12 LEDs = 4 RGB
   zones per ring; needs CONFIG for the driver + check vdd_mcu_3v3 label exists in our
   dtsi). Deliverable: /sys/class/leds stick RGB — dead on armada, a Holodor first.
3. **0605 wcd939x headsets-via-USBSS** — likely why the headphone jack is untested/dead.
4. **0050 + 0051 GPU stability (gx-gdsc collapse / gxpd votes on a8xx)** — candidates for
   the "slightly glitchy" UI; low risk, upstream-shaped.
5. **0033 aw88166 cancel-stale-start-work** — speaker amp race fix.
6. **1004 MCU version handshake, 0509 in-kernel paddles** — nice-to-have; 0509 would
   REPLACE our gpio-keys composite approach (InputPlumber config change needed — careful).
7. **1300 ranges: CONFLICTS** with armada's 1300-axis-deadzone we carry — same territory,
   reconcile by choosing one implementation when touching stick calibration.

Their 0046/0047 kept here for DTS reference/diffing (LED nodes, hap530 alternative
haptics, other deltas vs our ROCKNIX versions).
docs/reference/batocera-pocket/ has their fan daemon, charge-limit init, wifi-resilience
scripts — reference designs for our fan tuning + battery-care Decky panel.
