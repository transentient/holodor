# Games tested on the Retroid Pocket 5

Measured on Holodor with the frame-timing tools in `tools/rp5-bench`. Starting with `pocknix-steam` 0.1.0-61, **Holodor automatically seeds `1280x720` and a Low quality preset on first launch** for demanding 3D engines (Unreal 4/5, Unity, Creation Engine, CryEngine V, FromSoftware) while leaving 2D games at native `1920x1080`. Both the `1920x1080` default preset and the `1280x720` Low preset are shown below where measured (`balanced` / `performance` power profiles). Frame rates listed below are averages over 30 to 60 seconds in the named scene. All games run through Proton (`proton-cachyos-dxvk2` ARM64). Kernel `7.1.2-64`, Mesa `26.3.0-devel-12`.

| Game | Engine / API | Scene | fps | Notes |
|---|---|---|---|---|
| Vampire Survivors | 2D | gameplay, mid-game | 60, steady | Frame limit 60. Reference game. |
| Hades | 2D, DX11 | Tartarus, first chamber | 58–60 at 60 Hz | Smooth frame pacing on the default 60 Hz mode. |
| Hades II | The Forge, DX12 | Erebus, opening combat | **60, steady** | DirectX 12 (`VKD3D_FEATURE_LEVEL=12_1`). Controller works out of the box. |
| Celeste | 2D, Vulkan | prologue | 60, steady | Steam installs the Windows build. |
| Stardew Valley | 2D | menu / farm | 60 | Windows build. |
| Balatro | 2D | run / unlock screen | 60, steady | |
| Cuphead | Unity 2D, DX11 | Botanic Panic | **60, steady** | Periodic big-core affinity re-pinning keeps all threads on Cortex-A77 cores (`4–7`). |
| Hollow Knight | Unity 2D, DX11 | King's Pass | **60, steady** | Starting a new game skips the intro video (screen stays black until skipped). |
| Portal | Source, DX9, 32-bit | Testchamber 00 | 40, uneven | 32-bit games work out of the box. |
| Portal 2 | Source, DX9 | opening room | **60, steady** | `1920x1080` High in `balanced` mode. |
| The Talos Principle | Serious Engine, DX11 | attract scene | 57 with hitches | Runs through DXVK. |
| Octopath Traveler II | UE4, DX11 | New Delsta / title | 15 at 720p High; **60, steady at 720p Low** | Seeded to 720p Low (`bUseD3D12InGame=False`) on first launch (**4.0x faster** and `-11.8 C` cooler). |
| Dark Souls Remastered | FromSoftware, DX11 | Undead Asylum | 31 at 1080p High; **60, steady at 720p Low** | Seeded to 720p Low on first launch (**1.94x faster** and `-14.7 C` cooler). |
| Skyrim Special Edition | Creation Engine, DX11 | Helgen, outdoor dragon attack | **57 / 60 at 720p Low** | Launcher bypassed and 720p Low seeded automatically. Locked 60 fps in `performance` mode. |
| SIGNALIS | Unity, DX11 | Penrose-512 interior | 31 / 37 at 1080p High; **41 / 55 at 720p Low** | Seeded to 720p Low on first launch (`-15.4 C` cooler). |
| Alan Wake | Remedy, DX9 | Nightmare Lighthouse bridge | **45 / 54** at 1024x768 Default | Runs smoothly in both `balanced` and `performance` modes. |
| Prey | CryEngine V, DX11 | Morgan Yu's apartment | 12 / 13 at 1080p High; **40 / 43 at 720p Low** | `WINE_CPU_TOPOLOGY=4:4,5,6,7` + 720p Low (`sys_spec=1`) seeded automatically (**3.2x–3.4x faster**). |
| Risk of Rain 2 | Unity, DX11 | Distant Roost (Stage 1) | 9 / 10 at 1080p Default; **32 / 35 at 720p Low** | Seeded to 720p Low (`config.cfg` shadows/outlines/LOD) on first launch (**3.5x–3.7x faster**). |
| Deep Rock Galactic | UE4, DX11 | tutorial / space rig | 20 at 1080p Default; **28 / 29 at 720p Low** | Forced to DX11 (`bUseD3D12InGame=False`) and 720p Low automatically on first launch. |
| Subnautica | Unity, DX11 | Lifepod 5 fire / ocean | **27 at 720p Low** | Seeded to 720p Low on first launch. |
| Vanquish | DX9 | tutorial | 25 (game vsync) | |
| Outer Wilds | Unity, DX11 | Timber Hearth village | 10 at 1080p High; 23 at 720p Low | Seeded to 720p Low on first launch. |
| Observer | UE4, DX11 | apartment | 20–25 | Holodor disables Unreal's crashing HTTP thread (`bEnableHttp=false`) automatically. |
| Sekiro: Shadows Die Twice | FromSoftware, DX11 | Ashina Reservoir | **17 / 18 at 720p Low** | Seeded to 720p Low on first launch. GPU-bound on Adreno 650. |
| Jusant | UE5, DX12 only | | does not start | Requires DirectX 12 SM6.6 / UE5 features that the Snapdragon 865 GPU (`Adreno 650`) does not support. |

Notes:
- **First-launch 720p Low defaults**: When a supported 3D game is launched for the first time, `pocknix-proton-wrapper` seeds `1280x720` and Low quality settings (recording a `pocknix-gfx-defaults-seeded` marker in the game's prefix so any later in-game changes you make are kept).
- **CPU affinity & topology**: `pocknix-game-affinity` and `pocknix-proton-wrapper` keep game threads pinned to the 4 fast Cortex-A77 cores (`4–7`) and export `WINE_CPU_TOPOLOGY=4:4,5,6,7` so games size their thread pools for 4 cores and CryEngine V's CPU feature check succeeds.
- **DirectX 12 support**: DirectX 12 Feature Level `12_1` games that do not require Shader Model 6.6 / 8-bit storage (*Hades II*) run at 60 fps out of the box via `VKD3D_FEATURE_LEVEL=12_1`. Unreal Engine 4 games that offer both DX11 and DX12 are automatically configured for DX11 (`bUseD3D12InGame=False`).
- **Display refresh rate**: The built-in display runs at 60 Hz by default (`POCKNIX_GAMESCOPE_REFRESH_DEFAULT_LOWEST=1`). Enable the per-game "120 Hz Screen" toggle in Pocknix Control for lightweight 2D games that can hold 120 fps.
- **Native Linux games**: Valve's ARM64 Steam client does not include an x86 Linux runtime; Steam runs all PC games through Proton instead.

Docked (USB-C dock, 1080p 60 Hz HDMI output):
- Hades (menu): 60 fps locked.
- Dark Souls Remastered (Undead Asylum cell): 60 fps at 720p Low.
- Plugging into a USB-C dock switches video and audio to the external display automatically, and unplugging switches both back to the handheld.
