# Inquisitor review — the Cyberpunk fps program, 2026-08-14 → 2026-09-06

Independent adversarial review for Cliff. Sources: the four fps docs, HANDOFF.md, tools/ab/, the mesa-next / fex-rootfs / fex-emu / pocknix-steam packages, git log since 08-13, the pinned mesa tree. Device unreachable (one ssh attempt timed out), so no live reads. "Verified" = read in repo/log/source; "judgement" = mine.

## VERDICT

Ship the RC on the current stack (mesa-next-5 / fex-rootfs-3) with the recommended AAA config. Stop pinning mesa before release. The good work happened on 08-16 (instrumentation, the presented-fps meter, the shipped config); the driver work since 09-01 was a two-variable experiment whose losing arm carried a patch the team's own doc called a perf-feature disable, measured against a "native" baseline that was probably running the lsfg layer. Native 48 fps is not on this GPU at 720p by any driver change: ~91 % GPU-busy at 22 fps means 48 needs ~2.4× throughput. Holodor already presents 56.7 fps on the shipped config, above the Discord number. Reframe the goal and move on.

## 1. Stopping point for the RC?

**Yes. Ship A; do not chase another pin before release.**

- RC 20260906c carries the soaked stack (HANDOFF.md:57-59); the spot-check guards the -6/-4 leak (HANDOFF.md:62-68).
- Two driver generations moved native +4.6 % (run I) and −3.2 % (09-06). Run-to-run spread ±0.06 fps; driver-to-driver ±1 fps. That is the whole range curation offers, and it vanishes under lsfg 2x.
- The product number is 56.7 presented / ~28.4 real (bench-plan, 08-16 PM), measured at the DPU crtc counter. Nothing since has touched it.
- Fix before public: README.md:29-31 still says AAA ~20 fps is "root-caused to the young mainline display pipeline … not the GPU" — overturned 08-16, corrected only in INSTALL.md (ef0c740).

## 2. Anything else worth trying?

**Three bounded experiments cost under an hour each and would settle real questions; the rest is not worth it before release.** Ranked by gain × probability / cost:

1. **Isolate patch 0001 with an env var, no rebuild.** Mesa parses `FD_DEV_FEATURES=has_fs_tex_prefetch=0` at runtime (freedreno_dev_info.py:222; documented at freedreno_devices.py:125-128). Run A (-5 has no patches — a33a9b5's PKGBUILD is a bare `source=(mesa-main.tar.gz)`) with that env, 3 runs, ~15 min on the harness. A+env ≈ 21.4 → the patch was the whole regression and must never ship; ≈ 22.1 → the pin regressed. That is the one fact the next bump needs. 0001 was never a bug fix: upstream's comment is a "possibly needed" TODO (freedreno_devices.py:1396-1397), the landscape doc filed it as a corruption suspect, and it turns off a perf pass (ir3_context.c:118). Bundling it into a perf A/B was the design error.
2. **`TU_DEBUG=forcebin`, same harness, ~15 min.** In this pin (tu_util.cc:27, :512). Low odds — the threshold only bites passes ≤2 GMEM tiles (tu_util.cc:510), i.e. small post passes at 720p — but trivial cost and promised three times (HANDOFF.md:200, :498).
3. **Pin down which driver the RC default path loads, ~10 min:** game-tweaks.json, the FEX_APP_CONFIG json, `/proc/<pid>/environ`, map_files. §3 explains why.
4. **Resolution ladder as product tuning (Cliff's eyes, ~30 min):** FSR Balanced/Quality at 720p/900p vs shipped FSR Performance, each with lsfg 2x, judged on crtc presented fps and image quality. The only experiment that can make the game look better.

**Not worth it, and why:**
- LRZ reverts: eight upstream correctness commits; reverting = forking turnip, which the landscape doc rightly forbids. The whole pin delta is ≤3 %.
- Gamescope present-path work: ~4 ms/frame tax, gamescope ~6 % GPU (present-path doc, "INSTRUMENTATION RESULTS"); ≤ +15 % at best, days of work, next to the DPU modeset failure class. Backlog.
- 60 Hz mode, rotation micro-opt, cs_shared_mem, deck_emu: correctly parked. Leave them.
- Another mesa pin before release: two pins, two ±4 % results, a two-day loop each. No.
- Waiting on the Discord user: a non-answering witness with an unknown overlay is an anecdote, not a target.

## 3. Boondoggle audit

**Partly. 08-14 → 08-16 earned its keep; 09-01 → 09-06 mostly did not.** Since 08-13: 113 commits, ~20 on fps; ~7,000 words across four fps docs.

Genuinely valuable (verified, load-bearing):
- The 08-16 fdinfo instrumentation that replaced "wait-bound / 52 % GPU" with "91 % GPU-busy, ~4 ms tax" and killed a pacing rewrite before it started.
- The crtc `total_framecount` presented-fps meter, which settled "does lsfg actually present", and the shipped config it produced (56.7 presented vs 42.3 for in-game FG).
- The VSync-verified re-bench (22.98); the gmu-ddr doc's refusal to run a non-existent experiment.
- tools/ab: hands-free runs at ±0.06 spread is a real instrument, and it caught its own null result (three "B" runs on the un-quit A process).

The loops:
- **The unit under test was never pinned down.** 07-24: "no thunk ever engages" (fex-emu 003a06d). 08-13: thunk works (f16e268). 09-01: "VERIFIED FACT: x86 Proton games render through the in-sqsh x86 turnip" (HANDOFF.md:492-495; fex-rootfs header, lockstep rule). 09-06: the game maps the ARM driver (HANDOFF.md:118-120). Four assertions, each stated as fact. The 09-01 one cost a native x86 turnip build on a second machine plus a lockstep rule now called "moot" — and it is not moot: in the shipped wrapper the thunk is on **only** when lsfg is enabled with `thunkExperiment` (pocknix-proton-wrapper:103-104), so a player with lsfg off gets the x86 payload, which in fex-rootfs-3 is 26.1.5 — the version the 08-16 session blamed for a UCHE fault storm. Nobody knows which driver the RC default path runs. A 10-minute read, never done.
- **Tonight's "native" baseline probably ran lsfg.** The only wrapper path that enables the thunk also exports `LSFGVK_ENV=1` (wrapper:163), and HANDOFF.md:1847 records lsfg ON for Cyberpunk. The 09-06 block never checks `/proc/<pid>/environ`, though the bench doc's own TRAP paragraph demands it. The ~4 % drop from 22.98 (08-16, lsfg env-verified off) to 22.1 matches the ~2 ms/frame lsfg cost; "fresh install, kernel-25" is an unsupported attribution. A vs B survives (same config both arms); the absolute number does not. Judgement, provisional until the environ read.
- **Two-variable A/B.** Pin bump plus a known perf-pass disable in one arm, with a free runtime override available to separate them. Two days of staging (09-01, 02:28 → 14:14 by commit stamps) plus ~6.5 h on 09-06 (13:47 → 20:10; 14:05 → 17:40 lost to a sleeping device after the previous review's exact warning) to learn "−3.2 %, cause unknown".
- **The pair leaked into RC c's first pass** (HANDOFF.md:62-68): a re-spin caused by staging untested packages in the localrepo the image builder resumes from.
- **The @ice flip-flops.** 08-13: "48 = lsfg insertion ~24×2" (HANDOFF.md:2606-2608). 08-14: "NOT lsfg; Ultra SKU, 41 native / 48 FSR3.1" (HANDOFF.md:2398-2402). 08-15: "accounting difference; our 49/s ≈ his 48" (bench-plan, INFERRED). 09-06: "unexplained". Four positions on one screenshot, zero data from the source; the drafted questions sat unposted from 08-14 until Cliff asked in person.
- **Scope drift**: the campaign was declared CLOSED on 08-16 (HANDOFF.md:1998) and reopened 09-01 by a Reddit post about an Android binary, inside the sleep/battery focus the 09-05 review already flagged (§3f).

## 4. The 48 fps target

**For a native 48 at 720p:** GPU work per frame must drop from ~41 ms (0.91 × 45 ms) to ~17 ms — a 2.4× driver speed-up. The best rigorous community claim (faux123) is 6–8 %; two mesa generations here moved ±4 %. Even at quarter-res (FSR Performance) the game needs 27.3 ms. So on this silicon a "48" is presented (frame-generated), or a lower internal resolution plus an overlay counting output frames, or both. Armada's overlay shows presented fps; ours can too (`mangoapp_use_output_timing 1`, still unvalidated). Holodor's presented number on the shipped config is 56.7.

**Reframing:** not "match a stranger's counter" but "the best-looking ~30-fps base we can render, doubled by lsfg, with an overlay that tells the truth about the panel".

**A sentence Cliff can use:** "On this GPU, Cyberpunk renders ~22 fps native at 720p and ~30 at FSR Performance; with lsfg 2x the panel shows ~57, which is where the '48 fps' claims live — nobody has shown a native 48 on an Odin 3, and the silicon can't do it without a 2.4× driver miracle."

## What to do Monday

1. **Environ + route read on the device (10 min, agent, read-only):** game-tweaks.json, the FEX_APP_CONFIG json, `/proc/<pid>/environ` for LSFGVK/DISABLE_LSFGVK, map_files stamp — with Cyberpunk launched from Steam the way a player does. Record which driver and whether lsfg was live in tonight's runs. Amend the 09-06 table's caveat line.
2. **`FD_DEV_FEATURES=has_fs_tex_prefetch=0` on A, 3 runs (15 min, harness):** decides whether 0001 or the pin lost. Then drop 0001 from mesa-next's PKGBUILD regardless — it is a correctness hedge with no observed bug behind it.
3. **`TU_DEBUG=forcebin` on A, 3 runs (15 min, harness):** closes the item promised three times. Expect nothing.
4. **Fix README.md:29-31 (5 min):** replace the display-pipeline claim with INSTALL.md's 20–30 fps / GPU-driver wording.
5. **Publish RC 20260906c as-is** once the sleep gate closes. No mesa changes ride it. Post-release: one mesa bump per month, one variable per A/B, lsfg env-verified off, route recorded.
