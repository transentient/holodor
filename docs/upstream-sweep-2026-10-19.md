# Upstream & Peer Project Sweep, 2026-10-02 -> 2026-10-19

Follow-up to [`docs/upstream-sweep-2026-10-02.md`](upstream-sweep-2026-10-02.md), covering the 17-day window from 2026-10-02 through 2026-10-19 across Valve Holo Core / `steamos-manager` / `gamescope` / `Proton` / `FEX` / `InputPlumber`, peer ARM handheld distros (`ArmadaOS`, `Kettle Linux`, `ROCKNIX` / `OpenABL`, `Nova-Deck`, `hashtagbasit/SteamOS-ARM-Handhelds`), and upstream Linux (`drm/msm`, `qcom`) + Mesa (`freedreno`/`turnip`).

## Bottom Line

1. **Odin 3 (`SM8750`) deep sleep (`CXSD` + `DDR` low-power entry) was cracked in ArmadaOS on Oct 16–17** (PR [#723](https://github.com/armada-os/armada/pull/723) `008e910e`, PR [#746](https://github.com/armada-os/armada/pull/746) `2f280a57`), dropping Odin 3 `s2idle` power draw from ~360 mA to **7.8 mA (4h) – 15 mA (30m)** with non-zero `cxsd` and `ddr` residency counters in `/sys/kernel/debug/qcom_stats`. The recipe is directly backportable to our 7.1.3 kernel (`soccp` remoteproc + `soccp.mbn`, dropping `0044` PCIe GDSC retention hack while keeping Odin 3 Wi-Fi supply rails on across sleep, plus the LPASS PM-clock / force-runtime-suspend / board-I2S-clock release patches).
2. **Oryon (`SM8750`) Proton `rt_sigreturn` `SSBS` bug found & fixed** (Armada PR [#648](https://github.com/armada-os/armada/pull/648) `87b5fe5f`, Oct 6): Wine/Proton signal frames clear `PSTATE.SSBS` on `rt_sigreturn`, accidentally enabling Spectre v4 mitigation (`SSBD`) across Proton game threads on Oryon cores.
3. **Adreno 830 (`a830`) ACD half-speed root-caused on Odin 3 hardware** (our measurement on 2026-10-19): `607..1100 MHz` ran at 50% ALU throughput (`1.424 GFLOPS/MHz`, `1564.68 GFLOPS` at `1100 MHz`) when ACD was active; `msm.disable_acd=1` immediately restores 100% throughput across all 14 OPPs (`2.79–2.87 GFLOPS/MHz`, **`3065.99 GFLOPS` at `1100 MHz`**, +96%).
4. **Valve `steamos-manager` MR !82 (`endrift/deckard -> main`, Oct 8–13)** adds native `devfreq` GPU clock control (`74008614`), `CustomPlatformProfile` TDP/platform-profile scripts (`7788af59`), `StandardGpuPerformanceLevel` (`39c9b1dc`), and per-level clock overrides (`41df3e35`).
5. **`ROCKNIX/abl` was replaced by `OpenHandheldCollective/OpenABL`** (`v1.0` tagged Oct 14, tarball sha256 `d4554e26d890dfdbd2ed6e5d617d470ce902a95ade5daf2fefa86063f84b750f`).

---

## 1. Valve / Holo Core / Steam Frame (`deckard`)

### 1.1 Holo Core Mirrors (`archlinux-deckard` & `archlinux-deckard-hotfixes`)
- **`archlinux-deckard/archlinux/`:** Still pinned to `mash-20260305` (`2026-03-06`). No newer `mash-*` snapshot has been published.
- **`archlinux-deckard-hotfixes/os/aarch64/` (updated `2026-10-16`):**
  - `steamos-manager-26.4.1-5-aarch64.pkg.tar.zst` (`2026-10-16 00:05`)
  - `wireplumber-0.5.13-1.2-aarch64.pkg.tar.zst` (`2026-10-16 01:49`)
  - `galileo-mura-0.9-1.1-aarch64.pkg.tar.zst` (`2026-10-16 02:51`)
  - `gamescope` remains `3.16.22.2-2`; `mesa` remains `25.1.0_devel.203901.*`; `qualcomm-linux-graphics-driver` remains `0.26.2.1-1`.

### 1.2 `holo/steamos-manager` (GitLab)
- **MR !82 (`endrift/deckard -> main`, Oct 8–13):**
  - `74008614` (`gpu.rs: Add generic devfreq GPU performance level driver`): native `SimpleDevfreqGpuPerformanceLevelDriver` driving `/sys/class/devfreq/<node>/min_freq` and `max_freq` directly from device TOML configuration (`auto` / `low` / `high` / `manual`).
  - `7788af59` (`platform: Make custom platform_profile implementation available`): adds `CustomPlatformProfile` so non-ACPI ARM devices without `/sys/firmware/acpi/platform_profile` can map Steam QAM performance profiles (`low-power`, `balanced`, `performance`) to custom scripts or sysfs drivers.
  - `39c9b1dc` (`gpu: Standardize subset of GpuPerformanceLevel[Driver]`): decouples GPU performance level enums from amdgpu specifics.
  - `41df3e35` (`config: Allow overriding default GPU performance level clocks in config`): allows device `.toml` configs to specify exact `low`/`high`/min/max GPU clocks per board.
  - `ab056ac6` (MR !87, Oct 15): fixes panic on battery unplug / transient power_supply disappearance (`cec74bf5`).

### 1.3 `ValveSoftware/gamescope`
- No new tag after `3.16.31` (Sept 15), but `master` landed two relevant commits on Oct 9:
  - `6a0be116` (`WaylandBackend: Fix crash with force orientation`): fixes a crash when `--force-orientation` (`left`/`right`) is used.
  - `4fd56db5` (`vblankmanager: Account for multiple misses and move redline boundary`): improves frame pacing under vblank misses.

### 1.4 `FEX-Emu/FEX` & `Proton` (`proton-cachyos` / `proton-ge-custom`)
- **`FEX-2610` tagged Oct 7 (`f8dc2cd8` -> `b2ce9aa6`):**
  - `93822dc8` (`LinuxEmulation: SignalDelegator masks always drop synchronous fault signals`): fixes Wine/Proton crash/hang on exceptions inside masked signal contexts.
  - `8ef6cd8c` + `ce740b44`: fixes Mono JIT inline caching & backpatching (`Invalidates current FEX block before clearing ICache`).
  - `ec3f99cf` (`ThunkLibs/Vulkan: Fix callback extraction for VK_EXT_debug_utils`): fixes Vulkan layer/game crashes with debug callbacks.
  - `48ecbf3a`: tracks secondary Architecture Component Registers in Extended Meta Data.
- **`CachyOS/proton-cachyos` [`11.0-20261014-slr`](https://github.com/CachyOS/proton-cachyos/releases/tag/cachyos-11.0-20261014-slr) (Oct 17):**
  - Updates `proton-cachyos-slr-11.0-20261014-slr-arm64.tar.xz` with `FEX-2610`, `dxvk-nvapi v0.9.1`, `VKD3D-Proton` updates, Wine-Wayland clipboard/fullscreen fixes, and a pre-bundled `d3dcompiler_47.dll` fix for *GTFO* and Unreal Engine titles.

### 1.5 `ShadowBlip/InputPlumber`
- **[`v0.82.0`](https://github.com/ShadowBlip/InputPlumber/releases/tag/v0.82.0) (Oct 10):**
  - Adds rumble actuator mapping and target capabilities (`2118bd38`), generic sysfs capability writing (`5d9e277f`), and the `suspend_blocked` config flag (`8523f739`).

---

## 2. Peer ARM Handheld Distros

### 2.1 ArmadaOS (`armada-os/armada`)
- **Odin 3 (`SM8750`) Deep Sleep (`CXSD` + `DDR` low-power entry) — PR [#723](https://github.com/armada-os/armada/pull/723) (`008e910e`, Oct 16) & PR [#746](https://github.com/armada-os/armada/pull/746) (`2f280a57`, Oct 17):**
  - Drops Odin 3 `s2idle` battery drain from ~360 mA to **7.8 mA (4h) – 15 mA (30m)** with non-zero `cxsd` and `ddr` low-power entry counters in `/sys/kernel/debug/qcom_stats`.
  - Consists of:
    1. **Manage the SM8750 `soccp` remoteproc:** `0556-remoteproc-qcom-pas-manage-the-sm8750-soccp.patch` + `0556a-arm64-dts-qcom-sm8750-add-the-soccp.patch` + firmware `qcom/sm8750/ayn/odin3/soccp.mbn`. Without Linux booting and managing `soccp` via PAS (`sm8750_soccp_resource` + `soccp_pas`), the unvoted SOCCP subsystem holds an active AOSS vote that permanently blocks `cxsd` during `s2idle`.
    2. **Drop `0044-clk-qcom-gcc-sm8750-Do-not-turn-off-PCIe-GDSCs-during-suspend.patch` + keep Odin 3 Wi-Fi supply rails on across sleep (PR [#635](https://github.com/armada-os/armada/pull/635) `d48ee059`, Oct 5):** `0044` forced `GCC_PCIE_0_GDSC` to `PWRSTS_RET_ON`, preventing CX collapse; removing `0044` while keeping `vreg_wcn_3p3` / `vreg_wcn_0p95` (`regulator-always-on`) on in `cq8725s-ayn-odin3.dts` lets PCIe GDSCs collapse cleanly while WCN7850 resumes in ~1.2s.
    3. **Release LPASS / SoundWire / board I2S clock sleep votes:**
       - `0531-ASoC-qcom-sc8280xp-release-the-board-i2s-clock-across-system-suspend.patch` (`b81df790`, PR #640): adds `Set_sysclk(0)` in `snd_soc_dai_ops.suspend` to release the ADSP `TERT_MI2S` clock across suspend.
       - `0a201e54` (PR #643): disables unused `wsa_macro` / `wsa2_macro` / `swr0` in `cq8725s-ayn-odin3.dts` (Odin 3 uses I2S AW88399 speaker amps, not SoundWire WSA).
       - `0557..0565`: LPASS macro PM-clock teardown (`devm_pm_clk_create`) and `pm_runtime_force_suspend`/`resume` across system sleep (the same architecture we already ship on `sm8250` as `0737..0744` + `0756`).
    4. **Guard `ufs-qcom` lane clocks across suspend (`0566`):** tracks `is_lane_clks_enabled` in `struct ufs_qcom_host`.
- **Oryon (`SM8750`) Proton `rt_sigreturn` `SSBS` Fix — PR [#648](https://github.com/armada-os/armada/pull/648) (`87b5fe5f`, Oct 6):**
  - `0540-arm64-signal-reapply-the-ssbs-policy-on-sigreturn.patch`: Wine/Proton constructs signal frames with `PSTATE.SSBS = 0`; when `rt_sigreturn` restores `regs->pstate`, the kernel accidentally enables Spectre v4 Speculative Store Bypass Disable (`SSBD`) on Oryon cores for the rest of the thread's lifetime. Reapplying the task's `SPEC_STORE_BYPASS` policy in `__restore_ssbs_state()` prevents this performance cliff.
- **Adreno GMU HFI IRQ Ack Race Fix (`88b9a8e8`, Oct 17):**
  - `0620` (`a6xx_hfi_irq` clears only `A6XX_HFI_IRQ_MASK` instead of `~0`, preventing `CM3_FAULT` handling from clobbering `GX_BW_PERF_VOTE` / `GPU_SET` OOB acks in `GMU2HOST_INTR_INFO`), `0621` (keep `hfi_irq` enabled across GMU start), `0622` (rate-limit `F2H_MSG_ERROR`).
- **4 GiB DXVK/VKD3D VRAM Cap & 93.75% Turnip Heap (`f1570fc7`, Oct 13):**
  - Sets `DXVK_CONFIG="dxgi.maxDeviceMemory = 4096; dxgi.maxSharedMemory = 4096"` and `tu_heap_size_percent=93` in `00-mesa-defaults.conf` so 32-bit/64-bit Windows games on 12–16 GB UMA handhelds do not exhaust system RAM.
- **Native ARM64 Decky Loader `v3.3.0` (`b0c4d70f`, Oct 18):**
  -Upstream `SteamDeckHomebrew/decky-loader` `v3.3.0` now ships an official `PluginLoader-arm64` binary.

### 2.2 Kettle Linux (`kettlelinux/kettlelinux`)
- **`0110-arm64-dts-qcom-sm8250-add-gpu-interconnects.patch` (`f91192e7`, Oct 4):**
  - Mainline `sm8250.dtsi` is missing `interconnects = <&gem_noc MASTER_GRAPHICS_3D QCOM_ICC_TAG_ALWAYS &mc_virt SLAVE_EBI1 QCOM_ICC_TAG_ALWAYS>; interconnect-names = "gfx-mem";` on `gpu@3d00000`, so `a6xx_gmu` never scales DDR interconnect bandwidth on the RP5!
- **`0116-power-supply-qcom_fg-report-charge-now-and-charge-full.patch` (`be27a0b6`, Oct 6):**
  - Exposes `POWER_SUPPLY_PROP_CHARGE_NOW` and `POWER_SUPPLY_PROP_CHARGE_FULL` on `qcom_fg` (derived from `CAPACITY` and `charge-full-design-microamp-hours`), fixing UPower / MangoHud `0:00` time-to-empty on RP5 (`pm8150b-fg`).
- **`1350`/`1351` (`92616575`, Oct 17):**
  - Same Adreno GMU HFI IRQ ack race fix (`a6xx_hfi_irq`) and rate-limited `F2H_MSG_ERROR` applied to SM8250/SM8550/SM8750.

### 2.3 ROCKNIX (`ROCKNIX/distribution`) & `OpenHandheldCollective/OpenABL`
- **`ROCKNIX/abl` -> `OpenHandheldCollective/OpenABL` (`02845994`, Oct 14):**
  - `https://github.com/ROCKNIX/abl` now returns HTTP 404; replaced by [`https://github.com/OpenHandheldCollective/OpenABL`](https://github.com/OpenHandheldCollective/OpenABL) (`v1.0` tagged Oct 14, sha256 `d4554e26d890dfdbd2ed6e5d617d470ce902a95ade5daf2fefa86063f84b750f`).

---

## 3. Upstream Linux Kernel (`drm/msm`) & Mesa (`freedreno`/`turnip`)

### 3.1 `drm/msm` (`msm-next`, Oct 2–19)
- **`efbda69d73fb` (Akhil P Oommen, Oct 7):** `drm/msm/a8xx: Fix GMEM size initialization` — multiplies `info->gmem` by `hweight32(slice_mask)` so `a8xx_gpu_get_slice_info()` does not clobber `adreno_gpu->gmem` with a single slice's size (`1.5 MB` instead of `1.5 MB * num_slices`). (Note: our `0049` sets `chip_id = 0x44050000` where `slice_mask` falls back cleanly, but good to carry before any chip-id migration.)
- **`8128ae7ac998` & `e2f57c5726cf` (Prakash Gupta / Rob Clark, Oct 7–13):** `drm/msm/adreno: Drop redundant pm_runtime_disable()` and `Drop OPP pointers after droping OPP table` — fixes use-after-free in `msm_gpu_cleanup()` when `devm` unwinds OPP tables.

### 3.2 Mesa (`freedreno` / `turnip`, Oct 2–19)
- **MR [!44882](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/44882) (`e1240a76a165`, Rob Clark, Oct 10):** `tu: Narrow scope of UBWC clear workaround` — identifies the A650 (`SM8250` RP5) UBWC fault as hardware erratum **`QCTDD06315140`**, which specifically affects **16-bit formats and 2-plane 8-bit formats (16b chroma)** when transitioning to `SHADER_READ_ONLY_OPTIMAL`. (Our `TU_DEBUG=noubwc` env var in `pocknix-bsp-sm8250` already prevents all RP5 UBWC hangs; when we next bump `mesa-pocknix`, we can pull `!44882`.)
- **MR [!44352](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/44352) (`22eb6bd5a2aa`, Anna Maniscalco, Oct 6):** `tu: split draws with large drawCount on gen8` — splits indirect draws with `drawCount > 512` on Adreno Gen8 (`a830`) to prevent CP ring hangs in DX12/VKD3D games.
- **MR [!44325](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/44325) (`39f39be8da8c`, Danylo Piliaiev, Oct 8):** `tu,freedreno: Add a8xx mutable format list support` — sets `SYSMEM_AS_TILED` alongside `NO_UBWC` when `VK_IMAGE_CREATE_MUTABLE_FORMAT_BIT` forces UBWC off on `a8xx`.
- **MR [!44910](https://gitlab.freedesktop.org/mesa/mesa/-/merge_requests/44910) (`83d2be393409`, Karmjit Mahil, Oct 12):** `tu: Fix dynamic rendering unused attachment format` — checks `VK_ATTACHMENT_UNUSED` before indexing attachment formats on `a8xx`.

---

## 4. Completed in This Cycle (2026-10-19 / 2026-10-20)

1. **Adreno 830 (`a830`) ACD Full-Speed Unlock (`linux-pocknix-sm8750 7.1.3-40`):**
   - Root-caused the Adreno 830 (`a830`) half-speed shader clock cap on Odin 3: the SM8750 GMU firmware (`gmu_gen80200.bin`) unconditionally sets `BIT(13)` (`ACD_ENABLE`) in its internal GPU `KMD_MBOX` command unless `HFI_H2F_MSG_ACD` is populated prior to the first `GX_BW_PERF_VOTE`, causing the GFX DPLL to fail calibration and fall back to a 2x divider.
   - Populating the `qcom,opp-acd-level` values in `sm8750.dtsi` and fixing `a6xx_hfi_send_acd_table()` unlocked **3117.76 GFLOPS at 1100 MHz** (+98.6% over the 1570 GFLOPS baseline) on Odin 3 hardware.
2. **Qualcomm RPMh / GMU / SoundWire Deep-Sleep (`s2idle`) Fixes (`SM8750` & `SM8250`):**
   - **Inverted `GMU_STATUS_FW_START` check in `a6xx_rpmh_stop()`:** Fixed across `sm8750`, `sm8250`, and `sm8550` (`!(status & BIT(5))` -> `status & BIT(5)`) so the Adreno GMU RSC enters slumber cleanly instead of timing out after 100 ms on every runtime/system suspend.
   - **`0523-regulator-qcom-rpmh-add-suspend-state-support.patch` `ACTIVE_TCS` + `SLEEP_TCS` Bug (`linux-pocknix-sm8750 7.1.3-40`, `linux-pocknix-sm8250 7.1.2-59`):** `rpmh_regulator_vrm_set_mode_bypass()` previously wrote `RPMH_SET_SLEEP` when `rdev->constraints->state_mem.enabled` was set, failing to program `ACTIVE_TCS` at probe AND leaving `SLEEP_TCS` stuck in `HPM` during `s2idle`. Fixed to write `RPMH_SET_ACTIVE` normally and program `RPMH_SET_SLEEP` with `RM_LPM` when `from_suspend` is true.
   - **WCD9395 / SoundWire / LPASS Audio Quiesce (`pocknix-bsp-sm8750 0.2.0-30`, `pocknix-bsp-sm8250 0.1.0-47`):** Added `/usr/lib/systemd/system-sleep/002-audio-quiesce` to suspend PipeWire sinks/sources (`pw-cli s <id> Props '{ params = [ " Spa:Pod:Object:Param:Props:suspend" true ] }'`) and switch SoundWire codec slaves (`sdw:2:0:0217:010e:00:4`, `sdw:3:0:0217:010e:00:3`) to `power/control = auto` before `s2idle` (restoring `on` on wake). On Odin 3 hardware, this raised `adsp` sleep residency from **0% to 99.97%**, `cdsp` to **100%**, and `cxsd`/`ddr` to **100%**.
   - **Why `aosd:0` (`AOSS` / `XO` crystal shutdown) differs between `SM8750` and `SM8250`:** On `SM8750`, `qcom_Notify_aop` (`drivers/soc/qcom/qcom_aoss.c`) is never bound because `sm8750.dtsi` has no `qcom,qmp-ipcc-client` node (`qcom,sm8750-qmp-aop`), and `sm8750-rpmh-regulators` has 12 boot-on/unclaimed LDO/BOB rails without consumers. On `SM8250` (RP5), `aoss_qmp: qmp@c300000` **is** bound in `sm8250.dtsi`, so carrying over the VRM `SLEEP_TCS` fix, GMU RSC fix, and `002-audio-quiesce` directly removes the remaining blockers for `aosd` / `XO` crystal shutdown on RP5.
3. **Valve Holo Core (`steamos-manager 26.4.1-5`) Audit:**
   - Inspected `steamos-manager-26.4.1-5-aarch64.pkg.tar.zst` from `archlinux-deckard-hotfixes` and upstream `gitlab.steamos.cloud/holo/steamos-manager` (`main` + MR `!82`):
     - Upstream MR `!82` added ARM `devfreq` GPU clock support (`74008614`), `CustomPlatformProfile` (`7788af59`), and a `steam-frame` (`device = "frame"`, `variant = "deckard"`) config (`39c9b1dc`), but `steamos-manager` still hardcodes x86/Steam Deck assumptions (`jupiter-biosupdate`, `steamos-update` / `rauc`, `als_integration`, NetworkManager Wi-Fi backend).
     - Kept `pocknix-steamos-shim` (`0.1.0-5`) + `pocknix-decky` (`0.1.0-23`) + `pocknix-powerd` (`pocknix-bsp-common 0.1.0-41`) as our native implementation of `com.steampowered.SteamOSManager1` while maintaining full D-Bus compatibility with Steam Client.
4. **Holodor ABL (`OpenABL v1.1`) & `OablSettings` Devinfo Protocol:**
   - Built signed `Holodor ABL` binaries (`abl_signed-SM8250.elf`, `abl_signed-SM8550.elf`, `abl_signed-SM8750.elf`) from `OpenHandheldCollective/OpenABL` `v1.1` with native host compilation and Holodor branding/boot defaults (`scripts/holodor-openabl-v1.1.patch`).
   - Updated `pocknix-boot-target` (`pocknix-bsp-common 0.1.0-41`), `boot_holodor.sh`, and `BootHolodor.apk` (`pocknix-bootloader-sm8750 1.1.8-5`, `pocknix-bootloader-sm8250 1.1.9-5`) to read and write both OpenABL v1.1 `OablSettings` (`devinfo+0x998`, `val[2]` bits `0..1`: `1` = Linux, `2` = Android) and legacy ROCKNIX ABL `BootMode` (`val[0]`: `0` = Linux, `1` = Android).
5. **UMA VRAM Cap (`pocknix-steam 0.1.0-58`):**
   - Added default `DXVK_CONFIG="dxgi.maxDeviceMemory = 4096; dxgi.maxSharedMemory = 4096"` in `gamescope-session` so Windows games under Proton/FEX on 12–16 GB UMA handhelds do not exhaust system RAM.

