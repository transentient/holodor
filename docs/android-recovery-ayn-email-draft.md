# Draft: email to AYN (lucia@ayn.hk) — Android reboot loop

Context for Cliff: `lucia@ayn.hk` is the Google Drive account behind the EDL package
link you found in AYN Discord backscroll (July) — NOT someone you've corresponded
with, so the email claims no prior contact. Rewritten 2026-08-15 per your note:
short, simple English, one question. The technical detail lives in HANDOFF.md — if
they reply and want specifics, we answer with exactly what they ask for, one piece
at a time.

---

**Subject:** Odin 3 — Android reboot loop after factory reflash

Hello,

I hope you can help with an Odin 3 problem.

My Odin 3 is bootloader-unlocked. Android stopped booting, so I flashed the complete
December 2025 factory image (boot, dtbo, vbmeta, super) and wiped userdata and
metadata. All the images verify correctly. But Android still does not boot: it shows
the "device is corrupt" screen, then resets, over and over. It never reaches the boot
animation.

What could cause this?

Thank you,
[Cliff's sign-off]

---

## Follow-ups to keep in pocket (do NOT put these in the first email)

Ask only if/when Lucia engages, one at a time:

1. Is there a way to see the kernel log on a retail Odin 3? (Our vendor_boot cmdline
   is `console=ttynull` and there is no pstore/ramoops region — we are blind to the
   panic. A recommended cmdline/bootconfig change or an armed-ramdump mode would let
   us diagnose it ourselves.)
2. Is it a problem to flash December 2025 firmware onto a device that shipped on a
   later build (rollback index, metadata/encryption expectation)?
3. What does Android's first-stage init need on this device that Linux never touches
   (pvmfw/pKVM, vm-bootsys, a DSP image) that would hard-reset if unhappy?

## Superseded drafts

The 2026-08-14/15 long-form draft (dense, multi-question) and the Discord companion
post were dropped 2026-08-15: Discord was a dead end, and Cliff's guidance is that
emails to AYN must be terse — one simple question, plain English (recipient is likely
a native Chinese speaker). History is in git if ever needed.
