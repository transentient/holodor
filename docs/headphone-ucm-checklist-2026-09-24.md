# Headphone gain-staging checklist (WP3, 2026-09-24)

Device session for docs/plan-2026-09-24-next-release.md WP3 / agenda section E. One
variable at a time, on the Lexar debug card over ssh (`ssh deck@192.168.1.32`; root =
`systemd-run --wait --pipe --collect <cmd>`). Restart WirePlumber only at the Steam UI:
it drops Steam's sink mid-game.

Facts to keep in mind (agenda E, kernel-verified):
- `RX_RX0/RX_RX1 Digital Volume` is a true dB control: **84 = 0 dB**, 1 dB/step (-84..+40).
- `HPHL/HPHR Volume` 0..20 is **inverted**: 20 = register 0 = MAX PA gain. Its TLV is
  bogus in-kernel (0.07 dB/step, inherited from wcd938x), so **every dB number amixer or
  wpctl prints for HPH is meaningless** — count register steps and use your ears.
- `HP` = the stereo remap of HPHL+HPHR (AYN-Odin3.conf and base wcd939x/init.conf).
- Step 1 is what pkgrel 19 ships: `PlaybackMixerElem "HP"` in the Headphones device.

## 0. Baseline (before installing pkgrel 19)

```sh
amixer -c0 contents | grep -A2 -E "HPH[LR] Volume|RX_RX[01] Digital|RX HPH Mode|HPH PWR"
wpctl status | sed -n '/Sinks/,/Sources/p'
wpctl get-volume @DEFAULT_AUDIO_SINK@
pactl list sinks | grep -E "Name:|Volume:|Base Volume|active port"
```
Note the sink's `Volume:` line: with a **software** volume it shows a dB figure that
tracks the percentage exactly (40 % = -23.9 dB) and `pactl` prints no `Base Volume` step
for the hardware element. Listen at 40 % with a quiet track: this is the hiss reference.

## 1. Install pkgrel 19 and check the slider now drives the PA gain

```sh
# as root, at the Steam UI, from the package copied to /home/deck
pacman -U /home/deck/pocknix-bsp-sm8750-0.2.0-19-any.pkg.tar.zst
systemctl --user -M deck@ restart wireplumber pipewire   # or: as deck, systemctl --user restart wireplumber
sleep 3; wpctl status | sed -n '/Sinks/,/Sources/p'
```
Plug headphones, then:
```sh
wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.4;  amixer -c0 sget HP;  amixer -c0 cget name='HPHL Volume'
wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0;  amixer -c0 sget HP;  amixer -c0 cget name='HPHL Volume'
wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.6;  amixer -c0 sget HP;  amixer -c0 cget name='HPHL Volume'
amixer -c0 cget name='RX_RX0 Digital Volume'; amixer -c0 cget name='RX_RX1 Digital Volume'
```
PASS = `HPHL/HPHR Volume` register moves with the slider and `RX_RX0/1` stay at 84.
Ignore the dB columns. Then the ear test: same quiet track at 60 % vs the pkgrel-18 40 %.
FAIL modes and what they mean:
- Register stays at 20 whatever the slider does -> PipeWire could not use the element
  (bogus TLV: the mapped dB range is ~1.4 dB, so it may treat it as a switch). Go to 2.
- Slider is all-or-nothing / only the last few percent audible -> same cause. Go to 2.
- Speakers changed -> should not happen (Speaker device has no PlaybackMixerElem);
  check `wpctl status` shows both sinks and `alsactl` state is not overriding.

## 2. Fallback: lower the analog gain, keep software volume

Edit live: `vim /usr/share/alsa/ucm2/AYN/Odin3/AYN-Odin3.conf` (BootSequence) and
`vim /usr/share/alsa/ucm2/AYN/Odin3/HiFi.conf` (comment the PlaybackMixerElem line out).
```
	cset "name='HPHL Volume' 13"
	cset "name='HPHR Volume' 13"
```
Then `systemctl --user restart wireplumber` (as deck), re-plug the jack (BootSequence
runs at card init; if the registers did not change, `alsaucm -c SM8750-AYN reset` or
reboot), `amixer -c0 cget name='HPHL Volume'` shows 13.
A/B for hiss at equal loudness: `HPH 20 + sink 40 %` vs `HPH 13 + sink ~90 %`. Try 12 and
14 as well; the winner goes into the BootSequence for the respin (agenda says ~1.5 dB per
step is likely, unverified).

## 3. Class-H mode (only if hiss survives 1/2)

In HiFi.conf, Headphones EnableSequence, AFTER the rx-macro include line, add:
```
	EnableSequence [
		cset "name='RX HPH Mode' CLS_H_LOHIFI"
	]
```
(one device may carry one EnableSequence; merge the cset into the existing block after
the includes instead if UCM complains). Try in order: `CLS_H_LOHIFI`, `CLS_H_HIFI`,
`CLS_AB_HIFI`. Verify with `amixer -c0 cget name='RX HPH Mode'` after a re-plug.
Price each one: 5 minutes idle with headphones in, then
```sh
tail -n 6 /var/lib/pocknix/telemetry.csv     # current_now column; compare with ULP
```

## 4. Right-heavy

(a) Stored balance first:
```sh
wpctl get-volume @DEFAULT_AUDIO_SINK@
pactl list sinks | grep -A1 "Volume:"            # front-left vs front-right
ls -la /home/deck/.local/state/wireplumber/; grep -a -i -E "volume|channel" /home/deck/.local/state/wireplumber/default-nodes* /home/deck/.local/state/wireplumber/restore-stream 2>/dev/null | head
```
If L != R there, `wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.6` resets both channels.
(b) Registers per channel after the jack activates:
```sh
amixer -c0 cget name='RX_RX0 Digital Volume'; amixer -c0 cget name='RX_RX1 Digital Volume'
amixer -c0 cget name='HPHL Volume'; amixer -c0 cget name='HPHR Volume'
amixer -c0 contents | grep -A1 -E "HPH[LR]_(RDAC|COMP) Switch|HPH[LR] Switch"
```
Both RX_RX must read 84 (the q6apm reset quirk in HiFi.conf could re-zero one).
(c) Mono tone per channel at identical registers (as deck, at the Steam UI):
```sh
speaker-test -D pipewire -c2 -t sine -f 1000 -s 1 -l 1     # left only
speaker-test -D pipewire -c2 -t sine -f 1000 -s 2 -l 1     # right only
```
Equal registers but L quieter = the analog/USBSS path (wcd939x-usbss mux, kernel
0063 route-usbss-on-integrated-jack-insert), not gain staging. Last resort = a
compensating `RX_RX1 Digital Volume` offset in the BootSequence, documented as a
hardware quirk.

## 5. Ship

Whatever won: AYN-Odin3.conf BootSequence (+ HiFi.conf HPH mode line if 3 won) into
devices/sm8750/packages/pocknix-bsp-sm8750/, keep the JackControl/JackHWMute/priority
200 block, bump pkgrel, respin. Regression list: plug/unplug auto-switch, speakers
unaffected, suspend/resume audio, first-sound-after-idle.
