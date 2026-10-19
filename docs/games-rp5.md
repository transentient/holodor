# Games tested on the Retroid Pocket 5

Every game below was measured on Holodor at the RP5's full **1920x1080** resolution unless noted otherwise. Running at native 1080p pushes 2.25 times as many pixels as 720p, so for GPU-heavy 3D games, dropping the resolution to 1280x720 in Steam's per-game settings (**Properties** > **General** > **Resolution**) helps more than any in-game quality slider. Frame rates listed below are averages over 30 to 60 seconds in the named scene. All games run through Proton.

| Game | Engine / API | Scene | fps | Notes |
|---|---|---|---|---|
| Vampire Survivors | 2D | gameplay, mid-game | 60, steady | Frame limit 60. Reference game. |
| Hades | 2D, DX11 | first chamber | 58 at 60 Hz | Uneven frame pacing at 120 Hz; leave the screen at 60 Hz (default). |
| Celeste | 2D, Vulkan | prologue | 60, steady | Steam installs the Windows build. |
| Stardew Valley | 2D | menu | 60 | Windows build. |
| Dark Souls Remastered | DX11 | Undead Asylum | 28 | Uses `PROTONFIXES_DISABLE=1 %command%` (set automatically on Holodor). Sits on a white screen for about two minutes on first launch. |
| Octopath Traveler II | UE4, DX11 | title scene | 30 (game cap) | Runs warm: reaches about 90 C after 10 minutes. |
| Portal | Source, DX9, 32-bit | Testchamber 00 | 40, uneven | 32-bit games work out of the box. |
| Outer Wilds | Unity, DX11 | village | 10 at defaults, 23 on Low | Unity defaults to maximum quality on this GPU; turn shadows, AA, SSAO, water, and lighting down to Low in-game. |
| Risk of Rain 2 | Unity, DX11 | character select | 18 at defaults, 22 on Low | Same as Outer Wilds: turn shadows, SSAO, bloom, and LOD down in-game. |
| Deep Rock Galactic | UE4 | space rig | 14 (DX11) | Use the DX11 launch option; DX12 crashes at startup. |
| The Talos Principle | Serious Engine, DX11 | attract scene | 57 with hitches | Runs through DXVK; the in-game Vulkan renderer option is not selectable under Proton. |
| Vanquish | DX9 | tutorial | 25 (game vsync) | |
| Hollow Knight | Unity 2D, DX11 | menu | 52 | Starting a new game skips the intro video (screen stays black until skipped). |
| Jusant | UE5, DX12 only | | does not start | Requires DirectX 12 features that the Snapdragon 865 GPU does not support. |
| Observer | UE4, DX11 | | crashes 2 minutes in | Under investigation. |

Notes:
- The built-in display runs at 60 Hz by default. Enable the per-game "120 Hz Screen" toggle in Pocknix Control for lightweight 2D games that can hold 120 fps.
- DirectX 12 games do not run on the Adreno 650 GPU (including Jusant and Deep Rock Galactic's DX12 mode).
- Native Linux x86 games do not run because Valve's ARM64 Steam client does not include an x86 Linux runtime; Steam runs all PC games through Proton instead.
- Demanding 3D games reach around 90 C after 10 to 15 minutes and will lightly thermally throttle.

Docked (USB-C dock, 1080p 60 Hz HDMI output):
- Hades (menu): 60 fps locked.
- Dark Souls Remastered (Undead Asylum cell): 34 fps, even frame pacing.
- Plugging into a USB-C dock switches video and audio to the external display automatically, and unplugging switches both back to the handheld.
