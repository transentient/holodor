# DisplayPort (dock) audio: AFE port 0x6020 first-start timeout — PARKED 2026-10-08

Symptom: first PipeWire stream to the DP sink after boot or after the sink idles is silent;
`qcom-q6afe: AFE enable for port 0x6020 failed -110` (DEVICE_START not acked in 3 s). The next
stream plays. Repeated failures leave the port stuck (EALREADY) until reboot. Raw aplay never fails.

Tried (kernel 11/12/13, all on the RP5 docked, measured with the HDMI capture):
1. retry START on timeout, accept EALREADY as success -> prepare "succeeds", stream still silent.
2. immediate STOP + START -> STOP refused (DSP EFAILED), START = EALREADY, prepare fails.
3. settle 1 s, STOP, START, retry once -> same as 2.
What does work: the NEXT stream (close -> DAI shutdown -> port_stop; open -> hw_params incl. the
DP hdmi-codec prepare (msm_dp_audio_prepare: SDP/ACR/audio enable) -> prepare -> START). So the
DSP's START seems to need the DP audio enable to happen AFTER it was sent, or a longer settle.
Next ideas: (a) in q6afe_dai_prepare for DISPLAY_PORT_RX, on timeout return -EAGAIN-ish and let
the sink restart itself (PipeWire retries a failed start? no); (b) userspace: prime the port once
on DP jack connect (play 1 s silence twice via a udev/WirePlumber hook) and keep the sink from
suspending (session.suspend-timeout-seconds = 0 caused a card dropout once, retest cleanly);
(c) compare with downstream: ext_disp "cable notify" ordering before AFE start.
Workaround for the docs: if the dock is silent, play something again.
