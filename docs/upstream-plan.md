# Upstream plan (started 2026-10-02)

What we found that other people's devices also hit, and where each fix goes.
Cliff sends everything from his own accounts, signs off, and says plainly that
Claude helped (the kernel has rules for disclosing AI assistance; read the
current version before sending).

## 1. Headphones on WCD939x phones/laptops: left channel quieter (ready now)

**Who else has it:** alsa-ucm-conf issue #595 (X1E laptops, "quiet sounds panned
left", still open); PR #670 worked around it by turning off the RX-macro
compander for X1E. ROCKNIX PR #3091 calls the same path "unbalanced".

**What we know:** with the compander on, the gain data it sends to the codec
over SoundWire arrives misframed (cause in section 2). On the Odin 3 the left
side ends up 1.8–3.2 dB down. With both compander
stages off, L and R match within 0.1 dB at 100/75/50/25 % (bsp 24, measured on
the UCA202 rig, cold boot).

**Where it goes:** alsa-ucm-conf, a PR from Cliff's GitHub:
- `ucm2/codecs/wcd939x/HeadphoneEnableSeq.conf`: `HPHL_COMP Switch` and
  `HPHR_COMP Switch` to 0 (wcd938x already ships 0).
- Cite #595 and #670, include our L/R numbers.

**Before sending:** re-read upstream master (the file may have moved since
2026-10-01), and check that nothing else turns the compander back on.

## 2. Kernel: WCD939x SoundWire RX ports set up as "simple" (not ready)

**What we know:** mainline declares every WCD939x RX data port as
`SDW_DPN_SIMPLE`. For simple ports the SoundWire core never writes
DPn_OffsetCtrl2 or BlockCtrl3 (`drivers/soundwire/stream.c`). The Qualcomm
SoundWire controller sends the compander data (COMP port, DP3) with offset2 =
0x0b. Writing offset2 by hand (our one-shot module, `~/jack-measure/sdwpoke`)
lets the right channel's compander receive data. But at listening volumes the
compander still mutes or cuts both sides, so offset2 alone isn't the whole
fix. Nobody upstream has named this cause yet. The 2019 LKML thread chose
SIMPLE because WSA881x has no OffsetCtrl2.

**Where it goes:** linux-sound / SoundWire maintainers. Only once a patch makes
the compander path measure correct at every volume. A half-fix that changes
framing for everyone without fixing the sound will be rejected, and should be.

**Related, unmerged:** Marek's Nov-2025 wcd93x fixes; check where they stand
first.

## 3. ROCKNIX: HPH PCM ("HiFi") mode goes mono with the compander off (testing)

**What we know:** ROCKNIX's 0073 (HPH PCM mode) skips the crosstalk-filter
settings when the compander is off, while still switching the crosstalk filter
on. With zeroed settings the filter mixes L and R together: our measurements
put a left-only tone equally on both channels. Android and ROCKNIX's own
running state both have the settings written. Our fix:
`kernel/sm8750/patches/20-sm8750/0075-...patch` (writes them in both cases).

**Where it goes:** ROCKNIX (issue or PR against their 0073), once our Odin
tests pass. 0073 isn't in mainline, so there's nothing to send upstream for
this one.

## 4. RP5 (SM8250 / Adreno 650): UBWC bank bit on LPDDR4X (candidate)

**What we know:** mainline uses highest-bank-bit 16 for A650. The stock
Android driver reports 15 at runtime on the RP5 (LPDDR4X). Our 0700/0701 pick
15 from the memory type SMEM reports. This hasn't fixed the DXVK freeze on its
own, and we haven't yet shown a visible bug that it does fix.

**Where it goes:** linux-arm-msm, after the freeze investigation. It's a
correctness fix only if we can show a difference (rendering corruption,
display artifacts, or a measured mismatch). Otherwise it's just a note.

## Order

1. alsa-ucm-conf PR (section 1): now.
2. ROCKNIX report (section 3): after the Odin cold-boot/replug/sleep tests.
3. Kernel SoundWire (section 2): when we have a full fix.
4. RP5 HBB (section 4): only with evidence.
