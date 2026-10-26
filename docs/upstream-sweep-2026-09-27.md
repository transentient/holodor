# Upstream sweep delta, 2026-09-24 -> 2026-09-27 (agent sweep, read-only)

Method: gh API (ROCKNIX, Armada, Valve, FEX, Nova-Deck, MaSieS4Fun, Decky, InputPlumber), GitLab
API (mesa, gitlab.steamos.cloud), ISteamNews, kernel.org/cgit, deckard mirror listing, web search.
lore.kernel.org is 403 from fusor, so kernel-list patches are covered only via linux-next/cgit and
stable ChangeLogs. Dates verified from the source unless marked.

## Ranked: worth acting on for the NEXT release

1. **ROCKNIX ABL v1.1.9 released 2026-09-26; the v1.1.5-v1.1.8 tarballs are GONE from
   github.com/ROCKNIX/abl/releases** (only v1.1.9 has an asset). Notes: "bootcfw: simplify and
   speed up the boot process; stats: add support for more soc's; abl: display message when
   uninstalling cfw". Tarball sha256 2fc42c9cc60fe9eb33196785a8e92608f0ffbaa0b739b7051d948ba27a3bd747;
   SM8750 ELF 73d6a1cfd713811a4020ca9bf069f4395922e24056eca967d785c71b14dedc08 (258048 B).
   Armada's build broke on the vanished 1.1.8 URL; they vendored the four 1.1.8 ELFs into
   armada/abl/ (PR #560, 09-27, "soak the new builds before updating"); their SM8750 1.1.8 sha
   bedff34b99... matches our catalog row. Holodor: (a) README.provenance / flash_abl.sh point at
   the v1.1.7 tarball URL = 404 now; the 1.1.8 bump must vendor from Armada's abl/ or the
   device copy. (b) overlay/usr/share/holodor/rocknix-abl-releases.tsv stops at 1.1.8: add the
   four 1.1.9 rows or the installer's "identify ANY ROCKNIX ABL" fails for users on 1.1.9.
   (c) Do not move the kit to 1.1.9 yet ("bootcfw simplify" is exactly our dual-boot/model-menu
   code path). Pull the tsv rows now; bench-test 1.1.9; hold the kit at 1.1.8.
2. **Armada s2idle power series, PR #545 merged 09-26, kernel 7.2.6 base.** Odin 3 sleep at the
   USB input 0.71 -> 0.37 W. 0521 SM8750 PCIe suspend OPP (reverses their 09-23 #478 stance),
   0522 PCI host-common: only endpoints veto D3cold, 0523-0526 rpmh-regulator suspend states +
   regulator-state-mem, 0528-0530 ASoC: suspend the card and release AudioReach graphs across
   suspend ("a running game left a PCM open, so its graph kept the ADSP awake"; 0.091 -> 0.003
   W), 0903 battmgr constant_charge_current (0 = bypass charging), 1007 rsinput: cut the MCU
   3.3 V supply across sleep, DTS: Odin 3 codec rails to LPM in regulator-state-mem, PCIe WAKE#
   active-low, pwm-fan enable mode 3. Follow-up 0532 pwm-fan pwm1_sleep_charging (09-27, #561).
   https://github.com/armada-os/armada/pull/545. Biggest sleep-drain lever since 09-20; 0528-0530
   plausibly touch our dead-audio/dead-controls-after-s2idle family. Against 7.2.6; dry-run on
   7.1.3. Test next: 0521+0522, then 0528-0530, A/B with the sleep-power harness.
3. **Armada rsinput trigger fix, PR #556 (open, 09-26):** triggers on the Odin 3 top out at ~70 %
   because trigger_*_max served as both the MCU release reference (0x610) and the calibrated
   range; 6-line fix. Our 20-sm8750/1300-input-rsinput-ranges.patch only rescales sticks.
   **Check whether our triggers reach 32767 in Steam's calibration screen; pull if short.**
   InputPlumber keeps the stale axis range until restarted.
4. **Holodor is visible: 13 stars (incl. loki666 = ROCKNIX SM8x50 maintainer); first issue #1
   (FearlessSpiff, 09-26): "Controls not working after opening Steam Menu/Quicksettings" in
   Tennis Elbow 4, Steam Input on or off** = our known QAM freeze family, now user-reported.
   Retro Handhelds 09-25 article says "there's not actually a build of Holodor available to
   download" (wrong); VideoCardz 09-25 piece exists. Act: answer #1; one-line correction to
   Retro Handhelds with the download link.
5. **gamescope 3.16.30 tagged 09-24** ("Release 3.16.30 for SteamOS 3.10 (main branch)",
   ad2763da) = the 14 commits summarized 09-24. Rotation experiment target moves to 3.16.30
   (same enable_zenity caveat). Armada un-reverted to 3.16.29-ogc2 (09-24).
6. **Armada HDR direct scanout SM8550/SM8750, PR #559 merged 09-26:** DPU 10-bit plane formats,
   per-plane IGC + 3D LUT via LUTDMA, gamescope per-layer LUTs. "gamescope GPU time with an HDR
   game drops from ~435 ms per 4 s to 0." Phase 7 (K11/K12) material; after inline rotation.
7. **Mesa:** no a830 fix landed; the four gen8 fixes still main-only; staging/26.2 moved 09-26 so
   26.2.4 is imminent without them. New: !44352 "tu/a8xx: Split large indirect draws" (open,
   GPU faults on large indirect draws = fifth gen8 item); !44689 "tu: implement
   VK_QCOM_rotated_copy_commands" (09-24, ROCKNIX's sunshineinabox; rotation without a GPU pass,
   tested A610/A650, needs A7xx/A8xx). Nothing on 64-bit image atomics for a830. Pin advice
   unchanged (main >= 09-14); watch !44352.
8. **ROCKNIX PR #3377 "Qualcomm: Enable rotation universally" (09-25, open):** SDE-rotator m2m +
   whole-output plane rotation for SM6115/SM8250, gamescope 0013/0018/0019, 5-30 % GPU savings
   on Air X. SM8750 untouched (already has DPU inline rotation via 0068). Depends on mesa
   !44689. Watch: userspace half of our K11.
9. **Kernel:** 7.1.y is EOL (7.1.13 of 09-02 flagged EOL) = our 7.1.3 base is unmaintained.
   7.2.8 (09-25): drm/msm/dsi byte-clock rounding (= Armada 0048a), dpu pending peripheral
   flush, dp bandwidth fixes, RCU-free scheduler ring/VM objects, adreno autosuspend teardown.
   ROCKNIX SM8750 "7.2", Armada 7.2.6, Nova-Deck 7.2.7. linux-next: no new sm8750 DT since
   "sm8750: Add GPU clock & IOMMU nodes" (08-31, for 7.4); no cq8725s/Odin 3 DTS upstream.
   Strengthens the 7.2.x-readiness bundle; 7.2.8 is the target.
10. **FEX:** no tag after FEX-2609. DiskCache key strategy (b37aae72, 09-24) + auto-prune of
    old machine buckets (47557a61, 09-25). TSO: nothing. RootFS json unchanged. Wait for 2610.

## Other new items (watch / ignore)

- Valve: SteamOS 3.8.28 stable 09-25 ("Fixed 20-30 s startup delay in some games on non-Valve
  devices with no audio sources"; hid_steam Steam Controller 2026), 3.9.2 Beta 09-25; Steam Beta
  client 09-25 (sleep after 60 s idle when the account plays elsewhere; header flicker after
  wake); Frame OS 0.4.1. No ARM64/FEX/Proton-ARM/3rd-party line since the 09-21 rumble fix. No
  stable client since 09-01. Proton 11.0-2 still; proton-cachyos 20260703 still. Deckard: no
  new mash. steamos-manager unchanged (8e2883d0, 09-17). Armada PR #554 "add lepton" open.
- Armada misc: no release since 20260915. a41e41c9 09-24 perf profiles (balanced underclock
  restored); ff175647 09-25 pipewire +10 ms buffer vs post-sleep crackle; c474be88 stop
  graphical-session.target before plasma. Issues: #557 Odin 3 "Automatically Scale UI" off ->
  Gaming Mode inset at 98 %, STEAM_SCREEN_SCALE reset fixes (check ours); #547 Odin 3 5 GHz DFS
  ch52 beacon loss; #549 RP6 regdomain reset on every wake -> 15 s to see networks; #402 Odin 3
  "never charges" closed: user-side adsp_dtb.mbn lacking battery-auth config, firmware in TEST
  MODE (reference if a Holodor user reports no charging); #264 BT-in-sleep closed by #545.
  adtbloader 09-23/24: Android-DTBO device detection incl. Odin 3 (UEFI path). The dwc3-only
  autosuspend rule we copied is still Armada's current file.
- ROCKNIX misc: #3387 09-26 reverts "steam: honour the mangohud setting" (Steam wants system
  mangohud off + --mangoapp) = how we launch. installtointernal untouched (still msftdata).
  SM8750 tree untouched since 09-23.
- Decky Loader v3.2.10-pre1 (09-26): pyinstaller deps, plugin sort, file-picker fix. Stay on
  3.2.9 for packages/decky-loader.
- Nothing new: InputPlumber (0.81.0), Nova-Deck (09-23), MaSieS4Fun (09-23), the open ROCKNIX
  PRs from 09-24, Holo Core aarch64 preview, no new Reddit threads beyond the two 09-25 articles.

Scratch: the 1.1.9 tarball + Armada's vendored 1.1.8 SM8750 ELF were saved under the session
scratchpad (abl/); copy them into the repo before the session ends if the bump proceeds.
