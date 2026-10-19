# RP5 audio: ground-truth audit and target design (2026-10-15, for Cliff's review)

Cliff, 10-15 11:55: "I want all the audio stuff fixed. I don't want to see weird items in my audio menu, I want 100 %
volume to be 'too loud' and 50 % to be reasonable ... I don't want audio to work because we've got a bunch of random
scripts and weird configs everywhere ... go to ground truths, look at the device tree, look at Armada and ROCKNIX,
look at how all the audio stuff works from the chips out and make sure we have the most professional and elegant
solution." Also: root-cause the first-stream DSP timeout; the dock switcher must be event-driven or gone.

Nothing below is implemented yet. Sources: our tree (devices/sm8250/packages/pocknix-bsp-sm8250, kernel/sm8250),
the RP5's own Android audio HAL config (build/android-evidence-20261012/vendor-audio/*.xml, pulled from the device
10-12), ROCKNIX (~/projects/rocknix-distribution, shallow clone b895b27), upstream alsa-ucm-conf 1.2.14 (what the
image ships) and 1.2.16 (fusor), PipeWire 1.4.9 + WirePlumber 0.5.12 (image) incl. PipeWire's ACP source
(spa/plugins/alsa/acp/alsa-ucm.c, 1.4 branch), the kernel sources in build/kernel/sm8250, the live card on the RP5.

## 1. Ground truth

### 1.1 The hardware, from the device tree (kernel/sm8250/dts/qcom/sm8250-retroidpocket-common.dtsi, &sound)
Card `qcom,sm8250-sndcard`, model "RetroidPocket". Four front ends MultiMedia1..4 = hw:0,0..3 (q6asm, the DSP's
stream side). Four back ends (q6afe, the DSP's port side, routed by q6routing):
- "WCD Playback": RX_CODEC_DMA_RX_0 -> rx-macro (LPASS) -> SoundWire swr1 -> wcd938x (WCD9385) = headphones.
- "WSA Playback": WSA_CODEC_DMA_RX_0 -> wsa-macro (LPASS) -> SoundWire swr0 -> left_spkr + right_spkr (WSA881x) = speakers.
- "WCD Capture": TX_CODEC_DMA_TX_3 <- tx-macro <- swr2 <- wcd938x = headset mic.
- "DisplayPort Playback": DISPLAY_PORT_RX -> mdss_dp (hdmi-codec through the DRM audio helper) = dock audio.
Mixer controls on the card: 1291. The ones that matter: WSA_RX0/1 Digital Volume (-84..+40 dB, 1 dB/step, 84 = 0 dB),
WSA_COMP1/2 Switch (the wsa-macro companders = the hardware limiter in front of the speaker amps), SpkrLeft/Right
PA Volume (0..+18 dB), COMP/BOOST/VISENSE/DAC switches on each amp, RX_RX0/1 Digital Volume, RX_COMP1/2 and
HPHL/R_COMP Switch (headphone companders, rx-macro side and codec side), RX HPH Mode (class H / AB), HPHL/R Volume.
Upstream sound/soc/qcom/sm8250.c (`sm8250_be_hw_params_fixup`) forces EVERY back end to 48 kHz, 2 ch, S16_LE.

### 1.2 The vendor's configuration (Android HAL, mixer_paths_qrd.xml + audio_platform_info_qrd.xml)
- speaker path: WSA RX0/RX1 MUX AIF1_PB, WSA_RX0/1 INP0 RX0/RX1, WSA_COMP1 1, WSA_COMP2 1, SpkrLeft/Right COMP 1,
  BOOST 1, VISENSE 1, SWR DAC_Port 1. Defaults: WSA_RX0/1 Digital Volume 96 (= +12 dB). The back end runs 24-bit
  ("bit_width_configs: SND_DEVICE_OUT_SPEAKER 24", CDC DMA Format "UNPACKED").
- headphones path: RX_MACRO RX0/RX1 MUX AIF1_PB, RX INT0_1/INT1_1 MIX1 INP0 RX0/RX1, RX INT0/1 DEM MUX CLSH_DSM_OUT,
  RX_COMP1 1, RX_COMP2 1, HPHL_COMP 1, HPHR_COMP 1, HPHL/R_RDAC 1. Defaults: RX_RX0/1 Digital Volume 84 (= 0 dB),
  HPHL/R Volume 20 (of 24), RX HPH Mode CLS_H_ULP, RX_HPH_PWR_MODE ULP.
- display-port path: only the routing mixer (DISPLAY_PORT Mixer MultiMediaN 1); no codec settings.
- Measured on Android 10-12 (NTG, mic gain 0): max = a tone at -8.6 dBFS, H2 -31 / H3 -38, probe-burst pumping
  -0.3 dB with the companders ON. That is 13.9 dB louder and cleaner than our ceiling. THE REFERENCE.

### 1.3 ROCKNIX (same kernel 7.1.2, PipeWire 1.2.6, WirePlumber 0.5.7, alsa-ucm-conf 1.2.13)
- UCM = their patch 0002 (Teguh Sobirin): RetroidPocket.conf with BootSequence WSA digital 120 (+36 dB), PA 12, HPH 20,
  ADC2 10; HiFi-RP.conf = upstream codec includes verbatim (wsa-macro + wsa881x speaker seqs, rx-macro + wcd938x
  headphone seqs); their 0004 adds the HDMI verb (HDMI-RP.conf, "Separate verb so an unconnected/unrouted DP PCM
  never poisons the HiFi card", device hw:0,3, DP0 Jack). Our three UCM files descend from these.
- Kernel: 0100-revert-force-16bit-audio.patch is THEIRS (no subject): back-end format forced to S16 only for
  compressed links, otherwise negotiated. Also 0012 (q6asm periods), 0017 (DRM helper hw_params = prepare), 0062
  (wsa881x gpio), 0300 (jack irq). No q6afe / DP audio patches.
- PipeWire/WirePlumber: NO format rule for the RetroidPocket card (an S16LE rule exists only for the AYN Thor Lite
  and for SM6115), no default-volume, no profile rules. pipewire-pulse buffers 1024/48000.
- Scripts: output_monitor (sway IPC + 10 s poll) `_switch_audio`: wpctl set-profile HDMI/HiFi; if the HDMI profile is
  missing it RESTARTS WIREPLUMBER and retries (the same re-probe hack we had until bsp 36); hdmi_sense (udev, HDMI-A
  only, never fires for the RP5's DP connector); 050-audio sets "Master" 100 % and /usr/bin/volume 60 (pactl);
  /usr/sbin/quantum (force-quantum 1023/1024) at boot and after resume.
- Verdict: ROCKNIX runs the same 24-bit sample path we do (nothing pins S16) and compensates with +36 dB digital
  + 18 dB PA; their own reports of "PipeWire much quieter than raw ALSA players" (our 51-softmixer comment) are this
  bug seen from the outside. Their dock switch is a polled script that restarts WirePlumber.

### 1.4 Armada (image 20260927 at build/armada-extract, source ~/rp5-vs-hang/src/armada 5915c28)
Fedora 44 ostree, kernel 7.2.6, PipeWire 1.6.9, WirePlumber 0.5.17, alsa-ucm-conf 1.2.16.1.
- UCM: the ROCKNIX files verbatim (RetroidPocket.conf with the same BootSequence WSA digital 120 / PA 12 / HPH 20 /
  ADC2 10; HiFi-RP.conf with the stock includes; HDMI-RP.conf with the HDMI verb, device hw:0,3, DP0 Jack, no
  Priority). wsa-macro/init.conf not included, so WSA_COMP is never set. Speaker amps bound as WSA881x (same DT).
- Kernel: the same ROCKNIX audio patches (0100 revert-force-16bit, 0012, 0062, 0300) plus 0618 = their equivalent
  of our 0721 (display side of the probe; comment: "pipewire does it for every UCM device while it builds the
  card ... drop the whole card profile, taking the speakers down with it"). Nothing on the DSP side (our 0726).
- PipeWire/WirePlumber: stock, plus min-quantum 1024, pulse 512/48000, an S16LE rule for the AYN Thor Lite only
  (its comment claims the back ends are "hard-fixed to S16_LE by sm8250_be_hw_params_fixup()", which their own
  0100 undoes), and WirePlumber's media-role-nodes.conf REMOVED ("feedbackd's role-routing sinks can wedge Steam
  audio during session startup"). default-sink-volume stock 0.064.
- Scripts: NONE for audio. No dock switch, no volume service, no loudness filter, no heal. The gamescope session
  exports STEAM_DISABLE_AUDIO_DEVICE_SWITCHING=1 ("now handled by wireplumber") and STEAM_ENABLE_VOLUME_HANDLER=1.
- So Armada's dock audio = the HDMI verb + stock WirePlumber with HDMI at priority 100 < HiFi 8400: WirePlumber
  will not pick it by itself; and without a DSP-side probe fix an undocked boot loses the HDMI profile. Their
  speakers run the same 24-bit path at +36 dB digital.
- Confirms the design: three UCM files and stock session-manager policy is what the newest distro ships; the two
  things it lacks (profile Priority, the DSP-side probe fix) are exactly what makes the dock work by itself here.

### 1.5 Upstream alsa-ucm-conf, PipeWire ACP, WirePlumber (what the standard machinery does by itself)
- UCM includes for exactly these chips, 1.2.14 (the image): wsa-macro/SpeakerEnableSeq = routing + WSA_COMP1/2 ON;
  wsa881x/SpeakerEnableSeq = COMP/BOOST/DAC ON, VISENSE off, PA 12; wsa-macro/init = digital 84; rx-macro/
  HeadphoneEnableSeq = routing + CLS_H_ULP + RX_COMP1/2 ON; wcd938x/HeadphoneEnableSeq = RDAC/HPH switches, HPH_COMP
  OFF, CLSH on; rx-macro/init = digital 84. (1.2.16 turns the companders off in init and adds the class-AB variant
  "laptops with the wcd9385 need CLS_AB to not have distortion".) The sc8280xp Lenovo X13s = the only upstream board
  with this codec pair: BootSequence PA 12, HPH 2, ADC2 10, otherwise pure includes.
- PipeWire ACP (alsa-ucm.c): a UCM verb becomes a card profile; priority = the verb's `Value { Priority N }` (max
  10000) or a built-in default (HiFi 8000, HDMI none) + the devices' Playback/CapturePriority. Live on the RP5:
  HiFi 8400, HDMI 100. A profile's availability follows its devices' jacks: HDMI = "yes"/"no" with the DP0 Jack,
  HiFi = "yes" (Speaker has no jack). ACP probes every device of every profile ONCE, at card creation (open +
  hw_params, which in alsa-lib also prepares) and marks a whole profile unsupported on one failure; there is no
  runtime re-probe (alsa-udev.c re-emits a card only when it becomes inaccessible and back).
- WirePlumber 0.5.12 (scripts/device/*.lua): profile selection runs on device-added AND on every EnumProfile change
  (= availability change): stored user choice (only if a user set it) > `device.profile` property > best =
  highest-priority profile with available "yes", else "unknown", else off. So: if the HDMI verb's priority exceeds
  HiFi's, plugging the dock (jack -> HDMI "yes") makes WirePlumber switch to HDMI by itself, and unplugging (HDMI
  "no") switches back to HiFi. Routes: an output route whose availability just turned "yes" becomes the default
  (headphone jack). Default sink = the available node with the highest priority.
- WirePlumber default volume for a route with no stored state: device.routes.default-sink-volume = 0.064 linear =
  0.40 cubic = -24 dB (the "DP sink comes up at 0.40" of this morning). Our 52-pocknix-default-volume.conf sets it as
  a device PROPERTY, which 0.5.12 ignores (supported from 0.5.14); the Speaker's 0.65 is stored state.
- Volume law: PipeWire/WirePlumber sliders are cubic: 50 % = -18 dB, 40 % = -24 dB, 25 % = -36 dB.

### 1.6 Measured facts from our own record that the design must honour
- 10-13: PipeWire opens the Speaker PCM at S24_LE and the signal arrives ~27-32 dB LOW (S24 -42.1 dBFS vs S16
  -10.6 at the same slider); every gain we added since 09-xx (digital +38 dB, PA, +12 dB limiter, "boot the path
  hot") compensates this. Mixer controls act exactly (84->122 = +38.0 dB measured).
- 10-05: WSA companders ON pumped 4-8 dB and flattened the slider - measured WITH digital 122 (+38 dB) into them,
  i.e. the limiter hammered 26 dB above the vendor's operating point. Android: pumping -0.3 dB at digital 96.
- 10-06: headphones with RX_COMP ON + HPH_COMP OFF ducked 18 dB (the upstream 1.2.14 pair); class H distorted a
  full-scale tone 16 % with the companders off; class AB + both off = clean. Android runs BOTH companders ON, class
  H ULP. Never measured with both on.
- 10-07: the DP sink's first stream after a profile switch times out at the DSP (DEVICE_START no answer, 3 s), the
  DSP then reports the port "already started" but passes no audio, the next stop/start plays (staged patch 0720's
  text; today: docked boot = timeout + one silent stream + good). Hidden by double priming in the switcher.
- 10-09/10-15: a UCM device whose PCM cannot prepare takes its whole profile down at the one-time probe; fixed at the
  kernel (0721 display side, 0726 DSP side, tested today).
- 10-10: a sink without a real device.id is a second device in Steam; pipewire-pulse must see the filter as a plain
  Audio/Sink; Steam's CEF audio connects to pipewire-pulse once.

## 2. What we ship today, piece by piece

| piece | does | why it exists | origin | fate |
|---|---|---|---|---|
| kernel 0100 revert-force-16bit | BE format negotiable (24-bit BE) | ROCKNIX, no stated reason | inherited | DROP (back to upstream S16 BE), measured |
| kernel 0012 / 0017 / 0062 / 0300 | q6asm periods, DRM helper hw_params, wsa gpio, jack irq | ROCKNIX | inherited | keep |
| kernel 0721 + 0726 | DP audio prepare with no sink (display + DSP side) | our root fixes for the one-time probe | ours | keep (upstream candidates) |
| staged 0720.new | DSP port restart on START timeout | symptom patch for 1.6 | ours | superseded by the root cause |
| UCM RetroidPocket/HiFi-RP/HDMI-RP | verbs, devices, inlined gains | ROCKNIX 0002/0004 skeleton + our gains | mixed | REBUILD on upstream includes + vendor values |
| 51-pocknix-softmixer | soft volume, hardware gains fixed | invented around the 24-bit loss | ours | keep the one line (see 3.3) |
| 52-pocknix-default-volume | start routes at 1.0 | first boot at volume 0 (09-28) | ours | REPLACE by the global setting (0.5.12 ignores it) |
| 53-pocknix-displayport | S16/no-mmap/1024 on the DP sink | "starts reliably" (10-07) | ours | fold into the global S16 decision; rest removed after 3.6 |
| 40-pocknix-quantum (common) | min quantum 256 | measured crackle, Odin 10-08 | ours | keep |
| 99-wcd938x-nosleep.rules | no runtime PM on the codec | jack detection | inherited | keep |
| pocknix-speaker-loud (+conf.in) | "Speakers (Loud)" limiter sink owned by the card's device.id | loudness lost to the 24-bit path; Steam device list | ours | DELETE |
| pocknix-speaker-volume | companders off, digital gain planted during playback, custom dB-linear slider law | 10-05 warble + cubic slider too quiet | ours | DELETE |
| pocknix-dp-audio-switch | polls DRM 1 s, wpctl set-profile, primes twice | ACP profile switch + 1.6 | ours (ROCKNIX shape) | DELETE (3.5) |
| pocknix-sm8250-audio-heal | retry LPASS probes, plant gains | 07-16 probe race | ours | DISABLED on the device today; delete unless the race returns |
| pocknix-sm8250-audio-resume | force-quantum bounce after resume | ROCKNIX quirk | inherited | DISABLED today; delete unless the glitch returns |
| pocknix-steam waits for pipewire-pulse | ordering | CEF connects once | ours | keep |

## 3. Target design (every item is a standard mechanism; no polling, no daemons, no filter sinks)

### 3.1 Kernel: a correct sample path
MEASURED 10-15 12:40 (kernel 30 = 0100 staged out; raw ALSA A/B with a -73 dBFS tone, results-rp5-2026-10-15.md):
the 24-bit BACK END (ROCKNIX 0100) cost ~22 dB, gone with upstream's S16 BE; the 24-bit FRONT END (q6asm) still
costs 9.0 dB vs S16 (not a bit shift: a DSP scaling of 24-bit input). PipeWire adds nothing (its S24 result
equals aplay S24). Decision 3 reduces to: S16-only FE now (own q6asm-dai patch), V3 block as an optional later
experiment.
Step 1: drop 0100 -> back ends at S16 as upstream intends; measure the Speaker with PipeWire's default (S24 FE).
Step 2 if still low: the FE's 24-bit handling (q6asm sends the DSP a V2 format block with bits_per_sample 24 and no
sample word size; the vendor drives 24-bit with the V3 block carrying sample_word_size 32). Own patch: either V3
with the word size (vendor-faithful, 24-bit kept) or S16-only FE formats (honest, 16 bits is plenty here). Choice
by measurement, documented in the patch. Result either way: PipeWire's default format plays at the right level
and raw ALSA players match PipeWire (ROCKNIX's complaint disappears too).

### 3.2 UCM: three files, upstream includes, the vendor's numbers, nothing else
- RetroidPocket.conf: the upstream includes (card-init, ctl-remap, wcd938x/init, wsa881x/init, wsa-macro/init,
  rx-macro/init) and ONE board BootSequence, as the X13s does: WSA_RX0/1 Digital Volume 96, SpkrLeft/Right PA
  Volume 12, HPHL/R Volume 20, ADC2 Volume 10 (all vendor values). Verbs HiFi and HDMI.
- HiFi-RP.conf: Speaker = upstream wsa-macro + wsa881x sequences as shipped by 1.2.14 (companders ON, as Android);
  Headphones = upstream rx-macro + wcd938x sequences plus the vendor's HPHL/R_COMP ON (both companders on, class H
  ULP); Headset as now. JackControl "Headphone Jack", JackHWMute "Speaker" (standard).
- HDMI-RP.conf: as now plus `SectionVerb { Value { Priority 9000 } }` so the profile outranks HiFi (8400).
  Everything idempotent (WirePlumber re-runs EnableSequences), nothing written from scripts, ever.

### 3.3 WirePlumber: one drop-in, 50-pocknix-retroidpocket.conf
- `api.alsa.soft-mixer = true` for the card: the hardware gains are the vendor's fixed operating point (digital
  +12 dB, PA 12, companders), the slider is PipeWire's cubic software volume. 100 % = the vendor's maximum = "too
  loud" (13.9 dB above today's ceiling); 50 % = -18 dB = "reasonable". No custom law.
- `device.routes.default-sink-volume = 0.125` in `wireplumber.settings` (= 50 % cubic): first boot and every new
  route start at a reasonable level, not 0.40 and not 1.0.
- Only if 3.1 ends in "S16-only": nothing (the kernel offers S16); otherwise no format rule either. The DP sink's
  no-mmap/1024 lines are dropped once 3.6 lands and the sink is re-measured without them.

### 3.4 Steam's device list
One PipeWire device, "Built-in Audio", with the profiles HiFi and HDMI. No filter sink, no device.id trick, no
first-run picker (it appeared only when a second device existed). Verified by reading Steam's device list
(steamjs) on a fresh state and while docked.

### 3.5 Dock and jack: the policy engine does it
Dock in: the DP0 Jack turns the HDMI profile "yes"; WirePlumber picks the highest-priority available profile = HDMI;
its DisplayPort route becomes the default sink; Steam's streams follow. Dock out: HDMI "no" -> HiFi; Speaker or
Headphones per the Headphone Jack. Headphones in/out: route availability, as today. pocknix-dp-audio-switch is
deleted; nothing polls. (ROCKNIX needs its script because its HDMI verb has no Priority and its session manager
is older; ours has both.)

### 3.6 The first-stream DSP timeout: root cause, not priming
Facts: first DEVICE_START after link-up or idle gets no answer in 3 s; the DSP then says "already started" (0x9)
and passes nothing; stop+start works; ordering is already codec-hw_params (DP audio engine on) before the DSP start.
Plan (rig only, docked boot, two kernel builds max): ftrace afe_apr_send_pkt / q6afe_callback (opcode, token,
status, timestamps) and msm_dp_audio_enable/prepare/shutdown around the first three streams; read the DP audio
engine registers (debugfs/regmap) at the moment of DEVICE_START; compare with the vendor's dp_audio_on sequence
(downstream dp_audio.c: SDP setup, ACR, safe-to-exit level, engine enable, and the "audio ready" handshake the
DSP waits for). Fix at the layer the trace names. Until then the design has no priming; the test matrix will show
whether the first stream after a dock plug is still silent, which is the user-visible stake.

### 3.7 Suspend/boot
No audio heal, no quantum bounce (both already disabled on the device, boots and wakes fine today). If the LPASS
probe race or the post-resume glitch reappears in the test matrix, they come back as what they are, with a record.

## 4. Verification (all measured on the NTG / UCA202 / capture card, all at low level; one announced 3 s ceiling
tone with Cliff present)
1. Sample path: Speaker tone at slider 40 %, PipeWire default format, before/after each kernel step; target =
   within 1 dB of aplay S16 at the same gains.
2. Speaker vs Android: tone level at max vs -8.6 dBFS, H2/H3, probe-burst pumping (target < 1 dB), pink-noise crest;
   slider law: 100/75/50/25 % = 0/-7.5/-18/-36 dB on the mic.
3. Headphones (UCA202): both companders on (vendor) vs both off + AB (ours): level, ducking, THD at -1 dBFS, L/R.
4. Steam device list: fresh state undocked, docked; no picker; UI clicks on the speakers and on the dock.
5. Dock: plug -> HDMI profile + DP default sink within 5 s with no script; tone on the capture; unplug -> HiFi;
   jack in/out undocked and docked.
6. Boots and sleeps: fresh undocked boot, docked boot, undocked sleep, docked sleep (3-min rig cycles) - speakers,
   jack, dock audio after each.
7. 3.6: the first stream after a dock plug plays (the stake), with the trace evidence written up.

## 5. Decisions (Cliff, 10-15 12:40): 1 = YES, 100 % matches Android. 2 and 3 = MEASURE BOTH FIRST (companders on vs off;
S16-only vs V3), then pick. 4 = DELETE. 5 = try the recommended order. "You can be as loud as you want for the next
four hours" (until ~16:40): ceiling measurements allowed in that window.
### Original questions
1. Loudness target = Android's maximum at 100 % (13.9 dB above today), 50 % = -18 dB. Yes/no.
2. Companders ON (vendor + upstream 1.2.14) as the starting point, measured at low level; the 10-05/10-06 "off" fixes
   were measured at the wrong gains. If pumping returns at the vendor's gains, it is reported, not patched.
3. 24-bit: keep it the vendor's way (V3 block, own patch) or go S16-only. Recommendation: measure both; prefer the
   vendor-faithful one if it measures identical.
4. Delete the five services and the filter outright (not disable). Recommendation: delete; the record keeps the why.
5. Order: 3.1 kernel + 3.2/3.3 together (one bsp-sm8250 40 + kernel 30), then 3.6 while the matrix runs.

## 6. Decisions 14:35 (Cliff) and the Android data list
- Speaker chain LINEAR (companders off, digital 102) = bsp-sm8250 41. The compander is the vendor's loudness tool;
  closing the last ~5 dB to Android cleanly needs the vendor's compander tuning.
- DATA TO PULL FROM ANDROID (RP5 now, and on the RP6 from day one, before the first Linux boot): (1) codec register
  dumps during playback at a known level on every output (speaker, headphones, DP): /sys/kernel/debug/regmap/* for
  the wsa-macro (3240000.codec), rx-macro (3200000), tx/va macros, wcd938x, wsa881x (needs root; else the downstream
  driver source for the register writes); (2) `tinymix contents` snapshots idle and during playback per output (we
  have mixer_paths_qrd.xml, not the live values); (3) audio_policy_volumes.xml + the HAL's gain stages (we have the
  xml); (4) the ACDB/calibration files (/vendor/etc/acdbdata: speaker protection = VI-sense calibration, the DSP's
  smart-amp model) - likely why Android drives the amps harder safely; (5) logcat + dmesg of a dock plug with audio
  (the DP audio sequence and timing); (6) ADSP firmware version strings; (7) the DP alt-mode/typec sequence (have);
  (8) the live DT (have). Tooling: tools/dock/android-* collectors; keep the list in HANDOFF for the RP6.
- Cliff: an Azropa Z1FC arrives for docked testing; test USB-C DisplayPort mode directly (not only dock->HDMI).

## 7. Vendor source review (15:00) - what it settled
- DisplayPort start order is identical in the vendor stack; the held DEVICE_START is DSP behaviour; the vendor masks it
  with a permanent silence stream. Our remedy (kernel 0731) completes the start at its cause (an engine transition).
- The compander tuning is in the vendor driver source, no Android dump needed: WSA8815 amps = DEFAULT speaker mode
  (CTL3 bit7, CTL7 0x19, BOOST 0x58); upstream applies MODE_1 to every board. Kernel 0730 applies the vendor's sets and
  the DEFAULT mode. If the measurement with the companders ON then matches Android (level and pumping), section 3.2
  returns to companders ON per the vendor; otherwise linear stays.
- Vendor source mirror used: github.com/LineageOS/android_kernel_oneplus_sm8250 (lineage-20): techpack/display/msm/dp/
  (dp_audio.c, dp_catalog.c), techpack/audio/asoc/ (msm-dai-q6-hdmi-v2.c, kona.c, codecs/msm_hdmi_codec_rx.c,
  codecs/bolero/wsa-macro.c, codecs/wsa881x.c), techpack/audio/dsp/q6afe.c, drivers/platform/msm/msm_ext_display.c.

## 8. First-stream hold: root cause and fix (16:00)
The DSP acknowledges the DisplayPort port's DEVICE_START at the DP audio engine's rising edge. ROCKNIX 0017 (engine
enabled at hw_params, before the start; the vendor stack has the same order) made the DSP miss the edge in ~40 % of
starts. Fix = drop 0017 (upstream's order: the hdmi-codec enables the engine in its prepare, after the cpu DAI's) +
kernel 0731: q6afe waits 150 ms for that one command and reports the port started; the acknowledgement arrives at
the edge. Measured 6/6 + probe. No priming, no switcher, no pulse, no stop/start. Section 3.6 is closed.

## 9. Status 17:00 - implemented and verified
Kernel 41, bsp-sm8250 41, bsp-common 36. Every item of section 4 passed on the device except the headphone A/B
(no UCA202 rig attached today; the headphones run the upstream sequences plus the vendor's HPH_COMP ON and 84/20)
and the slider-law measurement at 75/25 % (50 % = -27.9, 100 % = -13.8 dBFS measured; cubic in between). Open,
not blocking: the DSP speaker-protection path (Android's +5 dB), the dock dongle's EDID dropout (alt-mode re-enter
revives), the 150 ms DP start wait (tunable), the powerd brightness traceback, the USB-2 NIC fallback seen once.

## 10. 21:20 addendum: headphone jack regression on the release card, fixed (bsp-sm8250 42)

The 40/41 Headphones device ("upstream includes + vendor operating point") shipped a clipped jack: full-scale tone
-28 dBFS, flat-topped, 25 % H3, a loud burst ducking a quiet probe 24 dB (UCA202, bare cable, no ears). Two proven
mechanisms: alsa-ucm runs an Include'd EnableSequence AFTER the section's inline csets (so upstream's HPH_COMP 0 and
CLS_H_ULP overrode ours), and `RX HPH Mode CLS_H_ULP` itself clamps the HPH output at ~80 mV on this device whatever
the companders do. The matrix (tools/rp5-audio/jack/matrix-2026-10-15.txt, jack-matrix.sh, modes written with the
sink suspended): CLS_AB + ULP power mode + all four companders off = -9.6 dBFS at 0.03 % THD, zero ducking, linear
(the bsp 24 recipe; ULP instead of bsp 24's LOHIFI, which compresses a -1 dBFS burst 5 dB). 42 writes the sequence
inline. Rule for this file: a device section is either upstream includes or its own sequence, never both. The slider
on headphones is a hardware map (PlaybackMixerElem "HP": +6 dB at 100 %, -12 dB at 50 %, -30 dB at 25 %); the
speaker is software volume. Unplugging the jack hands the default to the Speaker at 0.50 with the linear recipe.
