# Turnip on the Adreno 830 — landscape, fork assessment, and Holodor's graphics strategy

Researched 2026-09-01 (agent sweep, sources verified against mesa main that day).
Trigger: r/OdinHandheld post 1w3irn8 (faux123's Odin 3 turnip builds) + recurring
community claims about a830 driver maturity.

## faux123/turnip-faux123-driver — verdict

- What it is: upstream mesa main (26.3.0-devel, git-29c5f0ad44 — the same generation
  as our mesa-next) + a claimed 3-patch stack, shipped as an AdrenoTools .adpkg for
  Android (GameNative/Winlator). 100% Android/KGSL-side. The GitHub repo contains
  README + one release BINARY only — patch sources unpublished ("companion repo,
  ask in an issue").
- Who: faux123 = the veteran XDA kernel dev (GitHub since 2011). Claims ROCKNIX
  involvement — unverified (zero commits in ROCKNIX/distribution). Old
  gpl-violations history re withheld kernel sources; the binary-only pattern rhymes,
  though Mesa is MIT so it's legal.
- Credibility of the tech: HIGH. Two of his three bugs verified against mesa main
  same-day: (1) KGSL syncobj-merge null-pointer — real, still upstream, KGSL-only
  (we compile -Dfreedreno-kmds=msm, not that file); (2) binning threshold
  (tu_util.cc:510 skips binning ≤2 GMEM tiles) — real mechanism, kernel-agnostic,
  the ONE patch relevant to us; (3) gralloc DRM-modifier corruption — Android-WSI
  only (same area as open MR 43659). His methodology (86 Vulkan-Samples A/B vs the
  Qualcomm blob, throttle-gated, commit pinned in meta.json) is unusually rigorous;
  caveats honest ("translated games are CPU-bound"). No mesa MRs filed yet
  (no gitlab.freedesktop.org account); upstreaming = stated intent.
- Take today: nothing directly (Android binary, unpublished patches). Do: the
  forcebin experiment below; watch for his MRs; optionally open a friendly issue
  asking him to publish the companion repo (he invited it).

## Actionable candidates (ranked; 1–3 need NO patch — env-var/one-liner experiments)

1. **TU_DEBUG=forcebin A/B test** — reproduces faux123's binning-threshold idea with
   zero patching on our existing build. Upstream skips binning when a render pass
   covers ≤2 GMEM tiles; at 810p/900p under gamescope that may leave wins on the
   table (his figure: 6–8%, Android, single device; anecdote: Dysmantle 45→75fps
   at 900p, uncontrolled). If it wins: one-line threshold change in tu_util.cc.
2. **has_fs_tex_prefetch = False for a830** — upstream's OWN TODO
   (freedreno_devices.py:1390: "possibly also needed for a830…"); A810 and all
   a8xx_gen2 already disable it; **a830 is the only a8xx part still running with it
   enabled**. One-line device-props change. If we ever chase a830-only
   shader/texture corruption, suspect #1.
3. **64-bit image atomics hazard (UE5/VKD3D SM6.6)** — WinNative documents upstream
   5b87bbfad3b (Apr 2026) causing GPU hangs on a8xx in UE5-class titles (their
   disable_64b_image_atomics.py is the workaround). Path is ir3 codegen → plausibly
   bites our FEX/Proton stack. Already our known Expedition 33 fix candidate. If
   applied: scope to a8xx ONLY (their script also strips a7xx = RP6's a650... a7xx
   — do not carry that part).
4. cs_shared_mem_size 32→64KiB (whitebelyash dcbb41b2) — hardware truth UNVERIFIED;
   check the blob's maxComputeSharedMemorySize on the Odin 3 first. Wrong value =
   compute corruption. Not a cherry-pick until verified.
5. TU_DEBUG=deck_emu (Igalia, MR 38808, open) — advertise as Steam Deck for
   GPU-gating games. On-brand; low priority.
6. NOT worth taking: disable_gmem property, forced nocb (concurrent binning is
   already default-OFF upstream via drirc — the community "nocb fixes a830" advice
   is a no-op for us), UBWC gralloc hack, VK1.3-sans-multiview, phone enablement.

## The three community claims, grounded

**"A830 drivers are totally mature" — FALSE.** a8xx bring-up started upstream
2025-12 (mesa 26.0); a830 device props landed 2026-02; fixes still landing within
the last 3 weeks (chip-id 08-19, descriptor fix 08-25, GMEM+FDM clear 08-26). NO
Vulkan conformance submission exists for any a8xx turnip (the advertised 1.4
conformance inherits the a7xx/X1-85 submission). Missing: mesh shaders, RT
pipelines, shader_object, 16-bit storage arith, barycentrics. Mainline drm/msm has
NO a830 support at all yet — the kernel series hit the freedreno list 08-08 (R-b
08-17), realistically 6.19; our a830 runs on ROCKNIX's out-of-tree patches.
Counterweight: on faux123's measured samples, turnip already beats the Qualcomm
blob 5-of-6. Immature ≠ slow; it means unconformant, incomplete, moving weekly.

**"These devices weren't meant for 1080p" — UNSUPPORTED as hardware.** The GPU
drives 1440p/120 phone panels under the blob; a830 tile_max 16416×16384; a8xx GMEM
18–21MB. The real constraints the claim gestures at: chassis power envelope, driver
maturity, and CPU-side FEX translation (faux123: translated games are CPU-bound).
Resolution isn't the wall; translation and driver youth are.

**"Odin 3 SoC quite a bit more capable than Steam Deck's" — TRUE on paper, with
caveats.** ~3.4 TFLOPS FP32 estimated (community; Qualcomm publishes no ALU counts)
vs Van Gogh's official 1.6 TFLOPS = ~2x compute. Bandwidth near-parity (Deck 88GB/s
vs SM8750 ~84.8GB/s). Caveats that eat the paper advantage today: unconformant
young driver vs mature RADV; FEX translation tax (CPU-bound in practice);
handheld sustained-power envelope. One-liner: **more capable silicon, less capable
system — which is exactly why driver-side wins matter more for us than for the Deck.**

## Fork landscape (all Android/KGSL/AdrenoTools unless noted)

- whitebelyash/mesa-unified `turnip/gen8` — THE community a8xx hack stack ("ugly
  hacks", self-described); alive 08-07; several 2026 commits are actually
  Clark/Dobersek/Abbott backports, the rest phone-enablement hacks.
- StevenMXZ/Adreno-Tools-Drivers — biweekly CI of main+whitebelyash (894★, alive).
- The412Banner/Banners-Turnip — same recipe rebuilt hourly (137★, alive; documents
  provenance impeccably; a8xx leg compile-verified, not device-proven).
- K11MCH1/AdrenoToolsDrivers — the historical 5084★ repo, dormant since 02-24.
- MrPurple666/purple-turnip — 759★, releases through 08-17, recipe now hidden.
- WinNative-Emu/Drivers — alive 08-30, best-documented workaround scripts (incl.
  the 64b-atomics disable).
- p33k-a-b00/mesa-turnip-a830 — dead one-off.
- faux123 — new 08-31; only one verifying on an Odin 3 with upstreaming intent.

## Strategy (unchanged in kind, sharpened in degree)

Holodor already rolls its own mesa (mesa-next 26.3.0-devel, -Dfreedreno-kmds=msm,
turnip only). The right posture is what we do, done more deliberately: track mesa
main closely, carry a SMALL curated a830 patch layer (items 1–3 above as evidence
arrives), verify every community delta against upstream before adoption (most are
Android-only or already-upstream), and never fork-and-drift. Driver AUTHORSHIP
stays out of scope; driver CURATION is core competency. The Android hack-stacks
are a scouting network, not a parts supply: ~80% of their content is KGSL/gralloc/
phone enablement that cannot apply to us — check every patch's target layer first.

Bonus finding: a commenter reports Kingdom Hearts cutscene breakage on faux123's
Android a830 build — same title family as the KH rendering bugs in our mesa-next
pkgrel history. Weak-but-real evidence the KH issue is a turnip-family bug, not
Holodor-specific.
