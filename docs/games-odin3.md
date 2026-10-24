# Games tested on the AYN Odin 3

Measured on Holodor with the frame-timing tools in `tools/rp5-bench` (they work on both devices). Starting with `pocknix-steam` 0.1.0-61, **Holodor automatically seeds `1280x720` and a Low quality preset on first launch** for demanding 3D engines (Unreal 4/5, Unity, REDengine, Creation Engine, CryEngine V, id Tech 7, FromSoftware, Northlight, PlatinumGames, Hello Games) while leaving 2D games at native `1920x1080`. Both the `1920x1080` default preset and the `1280x720` Low preset are shown below where measured (`balanced` / `performance` power profiles). "fps" is the average over 30 to 60 seconds of active 3D gameplay in the named scene. All games ran through Proton (`proton-cachyos` ARM64). Kernel `7.1.3-47`, Mesa `26.3.0-devel-12`.

The Odin 3's screen is 120 Hz. By default, Holodor runs games at 60 Hz (`POCKNIX_GAMESCOPE_REFRESH_DEFAULT_LOWEST=1`) for even frame pacing and battery life; toggle "120 Hz Screen" in Pocknix Control for lightweight games you want to run at 120 fps. The Retroid Pocket 5 numbers are in [games-rp5.md](games-rp5.md); the same scene was used wherever possible.

| Game | Engine / API | Scene | fps | Notes |
|---|---|---|---|---|
| Vampire Survivors | 2D | run start | 60 (120 with 120 Hz toggle), flat | Reference game. RP5: 60. |
| Hades | 2D, DX11 | Tartarus, first chamber | 60 (120 with 120 Hz toggle), flat | RP5: 58–60. |
| Hades II | The Forge, DX12 | Erebus, opening combat | **60, flat** | DirectX 12 (`VKD3D_FEATURE_LEVEL=12_1`). Controller works out of the box (no unrecognized-controller prompt). RP5: 60. |
| Hollow Knight | Unity 2D, DX11 | King's Pass | 60 (120 with 120 Hz toggle), flat | Intro video plays. RP5: 60. |
| Celeste | 2D, Vulkan | prologue | 60, flat | Game's own 60 cap; smooth on the 60 Hz default panel mode. |
| Stardew Valley | 2D | menu / farm | 60, flat | Game's own cap. |
| Balatro | 2D | run / unlock screen | 60 (120 with 120 Hz toggle), flat | |
| Cuphead | Unity 2D, DX11 | Botanic Panic | 60, flat | Game's own cap. RP5: 60. |
| Dead Cells | 2D | Prisoners' Quarters | 60, flat | Game's own cap. |
| Terraria | XNA / .NET | menu | 60, flat | About 3 minutes of black screen at first launch, then fine. |
| Undertale | GameMaker | intro | 30 | Game's own cap. |
| SIGNALIS | Unity, DX11 | Penrose-512 interior | **60, flat** | RP5: 31 at 1080p; **41–55 at 720p Low**. |
| Portal | Source, DX9 | test chamber 00 | 60, flat | RP5: 40. |
| Portal 2 | Source, DX9 | opening room | 60, flat | RP5: 60. |
| Half-Life 2 | Source, DX9 | Point Insertion | 60, flat | |
| Fallout: New Vegas | Gamebryo, DX9 | Doc Mitchell's house | 60, flat | Launcher bypassed automatically. |
| Alan Wake | Remedy, DX9 | Nightmare Lighthouse bridge | **60, flat** | RP5: 45–54. |
| Dark Souls Remastered | FromSoftware, DX11 | Undead Asylum | **60, flat** | Game's own 60 cap. RP5: 31 at 1080p High; **60 at 720p Low**. |
| The Talos Principle | Serious Engine, DX11 | attract scene | 60, flat | RP5: 57. |
| Skyrim Special Edition | Creation Engine, DX11 | Helgen, outdoor dragon attack | **59, flat** at 1080p and 720p Low | Launcher bypassed and 720p Low seeded automatically. Clamped at Creation Engine's 59–60 Hz physics cap; 720p Low cuts frame-time spikes by 39%. RP5: **57–60 at 720p Low**. |
| Fallout 4 | Creation Engine, DX11 | pre-war house, 4 minutes of play | **60, flat** at 720p Low | Launcher bypassed automatically (`Fallout4Launcher.exe` -> `Fallout4.exe`). |
| Prey | CryEngine V, DX11 | Morgan Yu's apartment | 47 / 53 at 1080p High; **60, flat at 720p Low** | Seeded to 720p Low (`sys_spec=1`) on first launch. RP5: 12–13 at 1080p High; **40–43 at 720p Low**. |
| Control Ultimate Edition | Northlight, DX11 | Central Executive | 29 / 34 at 1080p Default; **60, flat at 720p Low** | Holodor routes to `Control_DX11.exe`, disables Coherent UI JIT (`JSC_useJIT=false`), and seeds 720p Low + EULA acceptance on first launch. |
| DOOM Eternal | id Tech 7, Vulkan | Hell on Earth, first combat | 38 at 720p Medium; **60, flat at 720p Low** | Launcher bypassed (`DOOMEternalx64vk.exe`) and 720p Low seeded automatically (`-18.8 C` cooler). |
| Subnautica | Unity, DX11 | Lifepod 5 fire / ocean | 19 at 1080p High; **60, flat at 720p Low** | Seeded to 720p Low on first launch. RP5: **27 at 720p Low**. |
| Risk of Rain 2 | Unity, DX11 | Distant Roost (Stage 1) | 40 / 41 at 1080p Default; **59 / 60 at 720p Low** | Seeded to 720p Low (`config.cfg` shadows/outlines/LOD) on first launch. RP5: 9–10 at 1080p; **32–35 at 720p Low**. |
| NieR: Automata | PlatinumGames, DX11 | prologue factory combat | 33 / 34 at 1080p High; **58 at 720p Low** | Seeded to 720p Low (MSAA and GI off) on first launch. |
| Outer Wilds | Unity, DX11 | Timber Hearth village | 24 / 27 at 1080p High; **58 / 60 at 720p Low** | Seeded to 720p Low on first launch. RP5: 10 at 1080p; 23 at Low. |
| Sekiro: Shadows Die Twice | FromSoftware, DX11 | Ashina Reservoir | 28 at 1080p High; **56 / 58 at 720p Low** | Seeded to 720p Low on first launch. Starts in offline mode. RP5: **17–18 at 720p Low**. |
| No Man's Sky | Hello Games, Vulkan | Planet Xiusa surface | 29 / 35 at 720p un-tuned; **48 / 57 at 720p Low + FSR 2** | Seeded to 720p Low with Native Vulkan FSR 2.0 Balanced and 4 High / 2 Low worker threads (+65% speedup). |
| ELDEN RING | FromSoftware, DX12 | Limgrave / Stranded Graveyard | 34 / 37 at 1080p High; **54 at 720p Low** | Offline mode (Easy Anti-Cheat bypassed automatically). 91% of frames at 60 fps pacing in `balanced` at 720p Low. |
| The Witcher 3: Wild Hunt | REDengine 3, DX12 (Next-Gen v4.04+) | Kaer Trolde Keep, Skellige | 30 / 34 at 1080p Default; **44 / 51 at 720p Low + FSR 2** | `REDprelauncher.exe` bypassed, working directory set to `bin/x64_dx12`, and 720p Low + FSR 2 Balanced seeded automatically. |
| Deep Rock Galactic | UE4, DX11 | tutorial drop pod | 39, flat | RP5: 20 at 1080p; **28 at 720p Low**. |
| Death Stranding | Decima, DX12 | first open-world hillside | 17 at 1080p Default; **28 at 720p Low** | In-game cutscenes run at 60. Rumble works. |
| Disco Elysium: The Final Cut | Unity, DX11 | Martinaise docks | 27, flat | |
| Sifu | UE4, DX11 | prologue courtyard | 26, flat | CPU-bound on the render thread. |
| DOOM (2016) | id Tech 6, Vulkan | The UAC, first room | 19 at 1080p; 25 at 720p | Holodor sets `+r_renderAPI 1` (Vulkan) automatically. |
| Observer | UE4, DX11 | main menu / apartment | 23 | Holodor disables Unreal's crashing HTTP thread (`bEnableHttp=false`) automatically. |
| Clair Obscur: Expedition 33 | UE5.4, DX12 | Lumière Harbor | 13 / 14 at 1080p Borderless; **19 / 22 at 720p Fullscreen Low** | Runs on DirectX 12 (`FullscreenMode=0`, 720p Low + TSR 50% seeded automatically). GPU-bound on UE5 Lumen/Nanite. |
| CONTROL Resonant | Northlight 2, DX12 | opening 3D scene | 16 at 720p Low | Runs on DirectX 12 (`-nodxr`, `VKD3D_CONFIG=single_queue,nodxr`). |
| Slay the Spire | Java | | does not start | The game's bundled x86 Java runtime exits at launch. |

Notes:
- **First-launch 720p Low defaults**: When a supported 3D game is launched for the first time, `pocknix-proton-wrapper` seeds `1280x720` and Low quality settings (recording a `pocknix-gfx-defaults-seeded` marker in the game's prefix so any later in-game changes you make are kept).
- **Power profiles**: The first number in `X / Y` rows is the default `balanced` profile (900 MHz GPU cap, cooler and quieter); the second is `performance` (1100 MHz GPU ceiling). You can set a per-game power profile in the Pocknix Control Quick Access Menu.
- **Thermal control**: Kernel `7.1.3-47` adds asymmetric Oryon CPU capacity awareness (`cpu6–7` Prime cores prioritized for main/render threads) and `85 C` passive thermal trip points, keeping sustained 3D gameplay around `72–84 C` instead of `100 C`.
- **Automatic launcher bypass**: Games with broken or mouse-only launchers (*The Witcher 3*, *Cyberpunk 2077*, *DOOM Eternal*, *ELDEN RING*, *Fallout 4*, *Skyrim Special Edition*, *Control*) are redirected straight to the game binary automatically.
- **Native Linux games**: Valve's ARM64 Steam client has no x86 Linux runtime, so all PC games run through Proton.
