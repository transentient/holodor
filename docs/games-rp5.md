# Games tested on the Retroid Pocket 5

Measured on Holodor with the frame-timing tools in `tools/rp5-bench`, screen at 1080p unless noted. "fps" is the average over 30 to 60 seconds of the scene named. All games ran through Proton (the ARM Steam client cannot run native Linux x86 games; see notes).

| Game | Engine / API | Scene | fps | Notes |
|---|---|---|---|---|
| Vampire Survivors | 2D | gameplay, mid-game | 60, steady | Frame limit 60. Reference game. |
| Hades | 2D, DX11 | first chamber | 58 at 60 Hz | Uneven at 120 Hz; leave the screen at 60 Hz (default). |
| Celeste | 2D, Vulkan | prologue | 60, steady | Steam installs the Windows build. |
| Stardew Valley | 2D | menu | 60 | Windows build. |
| Dark Souls Remastered | DX11 | Undead Asylum | 28 | Needs `PROTONFIXES_DISABLE=1 %command%` in launch options (set by default on Holodor). White screen for about two minutes at start is normal. |
| Octopath Traveler II | UE4, DX11 | title scene | 30 (game cap) | Hot: about 90 C after 10 minutes. |
| Portal | Source, DX9, 32-bit | Testchamber 00 | 40, uneven | 32-bit games work. |
| Outer Wilds | Unity, DX11 | village | 10 at defaults, 23 with shadows/AA/SSAO/water/lighting Low | Unity picks maximum quality on this GPU; lower it in the game. Resolution makes no difference. |
| Risk of Rain 2 | Unity, DX11 | character select | 18 at defaults, 22 with shadows/SSAO/bloom/LOD low | Same as Outer Wilds. |
| Deep Rock Galactic | UE4 | space rig | 14 (DX11) | DX12 launch option crashes. |
| The Talos Principle | Serious Engine, DX11 | attract scene | 57 with hitches | Runs through DXVK; its Vulkan renderer is not selectable under Proton. |
| Vanquish | DX9 | tutorial | 25 (game vsync) | |
| Hollow Knight | Unity 2D, DX11 | menu | 52 | New game: intro video does not play, screen stays black. Open. |
| Jusant | UE5, DX12 only | | does not start | Needs GPU features the Adreno 650 driver lacks. |
| Observer | UE4, DX11 | | crashes 2 minutes in | Open. |

Notes:
- The screen runs at 60 Hz by default. Steam's frame limit at 60 keeps it there; the per-game "120 Hz Screen" toggle in Pocknix Control is for games that hold 120 fps.
- DirectX 12 games do not run on this GPU (Jusant, Deep Rock Galactic's DX12 mode).
- Native Linux games: the ARM Steam client has no Linux runtime, so every x86 game runs through Proton.
- Heavy 3D games reach about 90 C after 10 to 15 minutes and throttle a little.
