# rp5-audio: speaker measurements with a USB mic on fusor (dev only)

Rig (2026-10-05): Cliff's RODE VideoMic NTG as a USB mic on fusor (ALSA card "NTG", `hw:1,0`, S24_3LE
stereo 48 kHz; needs sudo for arecord; its "Mic" capture control set to 8 dB, at 24 dB the room noise sat
at -23 dBFS). Mic ~25 cm from the RP5, nothing moved between runs.

- `spk.sh <label> <file-on-rp5> [secs]`: play on the RP5 speakers, record on fusor.
- `pumptest.py <wav>`: probe-and-burst test (steady 1 kHz probe at -30 dBFS + 220 Hz bursts, 0.5 s on/off).
  Reports how much a burst moves the probe = gain pumping ("warble").
- `thd.py <wav>`: level of a 1 kHz tone and its 2nd/3rd harmonics.
- `livesweep.sh <label> <file> <step-s> "<cset args>" ...`: change mixer controls WHILE a tone plays and
  report level/THD per step. Use this for every gain sweep: on the WSA speaker path a control written
  while the PCM is closed does not take effect reliably (levels came out 10/20 dB off); written during
  playback it is exact (1 dB per step), and an unchanged control repeats within 0.3 dB over 6 starts.
- `wavlevel.py`: rms/peak, optional tone level.

Findings so far are in HANDOFF.md (10-05 audio block).
