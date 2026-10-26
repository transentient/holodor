# Wi-Fi sulk root cause: post-resume roam → WCN7860 firmware crash

Hardware-proven 2026-09-03 (soak finding #4, HANDOFF) + research sweep same day.

## Mechanism (kernel log, boot d7df4d05, 2026-09-02 23:57)

wake → radio on → quick reconnect (first BSS deauths PREV_AUTH_NOT_VALID, second BSS
associates) → **+26s iwd roams** to the AP's other radio ("disconnect from AP …:11 for new
auth to …:19"), reassoc completes → **0.6s later the firmware asserts and ath12k
auto-recovers** ("mhi Requested to power ON", CE/srng ring dump, "pdev 0 successfully
recovered") → reconnect attempts fail briefly (auth timeouts; AP answers status 30
"rejected association temporarily, comeback 2s" = normal after a client vanished without
deauth) → iwd gives up into autoconnect_full → dead air; NM "failed" (retries=0 by design).
Frequency: roam on ~every other resume; ~3 of 5 roams crash the fw. A re-sleep/wake does a
full mhi power-on and fixes it — which is what Cliff has been doing by hand.

Second defect: **pocknix-wifi-heal has never run** — sleep.d/post/000-wifi launches it with
`setsid … &` inside systemd-suspend.service; setsid detaches the session, not the cgroup,
so systemd kills it when the hooks finish (006-wake-grace uses systemd-run and survives).
Even alive, its 20s window closes before the +26s roam.

## Firmware: no newer Linux-loadable WCN7860 build exists publicly

- WCN7860 = "GNG" (Ganges) family, distinct from WCN7850 "HMT". No WCN7860 dir in
  codelinaro ath12k-firmware or linux-firmware; HMT blobs are NOT usable (different file
  set/size; WCN7860 needs aux_ucode.bin, bdwlan.elf, qdss.cfg; support itself is
  out-of-tree — ROCKNIX/Armada patches 0039–0041; not in mainline even at 7.3-rc1).
- The whole Linux community runs ONE build: **WLAN.GNG.1.0-04065 (2025-08-09)** from
  ROCKNIX/extra-firmware SM8750/ath12k/WCN7860/hw2.0 (e0d9fb28 + d7afd129, byte-identical
  in armbian/firmware PR #136).
- Newer GNG lines exist ONLY inside Android OTAs (GNG.2.0-01243/01294/01319 on OnePlus/
  nubia SM8750 phones). Whether AYN's Odin 3 OTAs (v1.0.0.151 2026-02, .187 2026-06) carry
  a newer wlan blob is UNKNOWN — cheap check on stock Android during the Phase-2 EDL
  block: `cat /vendor/firmware_mnt/verinfo/ver_info.txt` (key wlan_gng) and the blobs in
  /vendor/firmware_mnt/image/ (amss20.bin→amss.bin, aux_ucode.bin, bdwlan.elf, m3.bin,
  regdb.bin, qdss_trace_config.cfg→qdss.cfg — same set ROCKNIX ships). Cross-device
  GNG.2.0 blobs = risky (board data / QMI behaviour vs patches 0040/0041).

## No matching upstream fix; nearest neighbours (all relevant to recovery, not the assert)

- ROCKNIX/distribution#3171 (open 08-12): same fw 04065 asserts on fully-passive multi-band
  scans (iwd's no-SSID periodic scan) → patches 0615 (no passive multiband scan on wcn7860)
  + 0616 (split scan into channel chunks). Different trigger, same firmware fragility;
  post-crash periodic scans likely hit this too.
- ROCKNIX/distribution#3189 (open 08-15): ath12k never sends scan_priority → every host
  scan runs VERY_LOW behind fw's 11d scan → "scan event start failed reason 4", slow
  erratic reconnect after radio bring-up. One-line patch 1020. Directly relevant to our
  post-recovery reconnect failures.
- Red Hat series (Tornos, v2 2026-08-04, unmerged): "fix MLO station firmware crash
  recovery" + "prevent scan during firmware recovery" (NULL deref if userspace scans while
  MHI powers on). Tested WCN7850.
- ath12k list 2026-07: regulatory domain reset on resume → ~7s reconnect delay (unmerged
  "restore country code during resume").
- Linux 7.2 vs 7.1.3: 54 ath12k commits, none touch roam/recovery; the hardening ones are
  already in linux-7.1.y (7.1.13). Bumping to 7.2 won't change this bug.

## iwd knobs (verified in iwd 3.12 source: iwd.config.rst, station.c)

- **`[Scan] DisableRoamingScan=true`** gates `station_cannot_roam()` → blocks BOTH low-RSSI
  roams AND 802.11v BTM-directed roams (the BTM handler then only blacklists the current
  BSS as AP_BUSY for [Blacklist] InitialAccessPointBusyTimeout=30s and returns). This is
  the only way to make iwd ignore BTM; no dedicated key. Side effect: sticky weak BSS until
  the link drops; a mesh may kick the client (then iwd reconnects, avoiding that BSS 30s).
- RoamThreshold/RoamThreshold5G (our -85/-85) do NOT stop BTM roams; the Critical pair only
  applies with a D-Bus Affinity set (inert for us). `[Rank] BandModifier5GHz` biases
  initial BSS choice toward 5GHz (useful once roaming is off).
- Our client never advertises BSS-Transition in ext-capa (ath12k STA ext-capa lacks it);
  spec-following APs wouldn't send BTM, mesh vendors often do anyway. `iwd -d` shows
  "roam: BSS transition received from AP" for BTM vs roam-trigger timeout for RSSI roams.
- ROCKNIX: wifi fully down across sleep (wifictl disable/enable) + [Scan]
  MaximumPeriodicScanInterval=30 + [DriverQuirks] PowerSaveDisable=ath12k*. Armada: NM
  keeps devices up across suspend (opposite). Neither sets roam knobs. NOTE: our
  000-wifi pre/post already do radio off/on across sleep — the roam happens AFTER the
  fresh post-resume connect, so "down across sleep" alone does not dodge it for us.

## Ranked plan

1. **`[Scan] DisableRoamingScan=true`** (+ `[Rank] BandModifier5GHz=1.2`-ish so the initial
   pick is 5GHz) — config-only, kills the trigger. Medium-high confidence. Soak-eligible.
2. **Heal fix**: launch via `systemd-run --collect`; watch ~90s post-resume; on unhealthy
   → `nmcli connection up <profile>` (gentle) → radio cycle → existing PCIe reset. Also
   react to the fw-recovery event any time (journal/udev trigger), not just post-resume.
3. Kernel-25 cargo: ROCKNIX 1020 (scan priority) + 0615/0616 (passive multiband scan) —
   faster, saner reconnects after any recovery.
4. Phase-2 stock-Android check of ver_info.txt wlan_gng; lift a newer AYN GNG set if one
   exists (keep AYN's board-2.bin/bdwlan.elf pairing).
5. Watch the Red Hat recovery series; kernel 7.1.13 bump at next cycle (free hardening).
6. Router-side band-steering off = confirmation experiment only (masks the bug for users).
