# Games tested on the AYN Odin 3

Measured on Holodor with the frame-timing tools in `tools/rp5-bench` (they work on both devices). **Every number is at the screen's full 1920x1080** unless the row says otherwise. That is the hardest case: 1080p is 2.25 times the pixels of 720p, and for the games where the GPU is the limit, dropping the resolution in Steam's per-game settings (Properties > Resolution) gains more than any in-game setting. A 720p comparison is noted where it was measured. "fps" is the average over 30 to 45 seconds of the scene named. All games ran through Proton (the ARM Steam client cannot run native Linux x86 games; see notes). Kernel 7.1.3-33, the shipped one. Device plugged in, battery full.

The Odin 3's screen is 120 Hz. In this pass the 60 fps frame limit was not limiting (see notes), so 2D games ran at 120 fps with the GPU at full clock. The Retroid Pocket 5 numbers are in [games-rp5.md](games-rp5.md); the same scene was used wherever it could be reached.

| Game | Engine / API | Scene | fps | Notes |
|---|---|---|---|---|
| Vampire Survivors | 2D | run start | 120, flat | Reference game. RP5: 60. |
| Hades | 2D, DX11 | Tartarus, first chamber | 120, flat | RP5: 58. |
| Hollow Knight | Unity 2D, DX11 | King's Pass | 120, flat | Intro video plays. RP5: 52, no intro. |
| Celeste | 2D, Vulkan | prologue | 60, flat | Game's own 60 cap; on the 120 Hz panel frames show for 1, 2 or 3 refreshes (slight judder). |
| Stardew Valley | 2D | menu | 60, flat | Game's own cap. |
| Balatro | 2D | unlock screen | 120, flat | |
| Dark Souls Remastered | DX11 | Undead Asylum, standing | 60, flat | Game's own cap. About 2.5 minutes to the title on first launch. RP5: 28. |
| The Talos Principle | Serious Engine, DX11 | attract scene | 66, flat | RP5: 57 with hitches. |
| Portal | Source, DX9 | test chamber 00 | 65, uneven | Frames alternate 13 and 21 ms. |
| Risk of Rain 2 | Unity, DX11 | character select | 46, flat | RP5: 18. |
| Deep Rock Galactic | UE4, DX11 | tutorial drop pod | 39, flat | CPU cores reached 100 C, fan at maximum. RP5: 14. |
| Observer | UE4, DX11 | main menu | 23 | Crashes about 2 minutes in (same as the RP5); see notes for the fix being tested. |
| Outer Wilds | Unity, DX11 | village, start of loop | 21 at default (maximum), **41 at Low** | Shadows, SSAO, water, lighting and AA quality to Low. RP5: 10. |
| DOOM (2016) | id Tech 6, Vulkan | The UAC, first room | 19; 25 at 720p | Holodor sets the Vulkan renderer for it (the game's default OpenGL path runs at about 1 fps). Its own settings are already at Low; the limit is the CPU, so resolution does little. |
| Portal 2 | Source, DX9 | opening room | 60, flat | |
| Half-Life 2 | Source, DX9 | Point Insertion | 60, flat | |
| Cuphead | Unity 2D | storybook intro | 60, flat | Game's own cap. |
| Dead Cells | 2D | Prisoners' Quarters | 60, flat | Game's own cap. |
| Terraria | XNA / .NET | menu | 60, flat | About 3 minutes of black screen at launch, then fine. |
| Undertale | GameMaker | intro | 30 | Game's own cap. |
| Fallout 4 | Creation Engine, DX11 | pre-war house, 4 minutes of play | **60, flat** at 720p Low | The launcher picks "Ultra" by itself; choose Low and 1280x720 in its Options. Outdoors not yet measured. |
| Subnautica | Unity, DX11 | life pod, game start | 19 at High (default), **51 at Low** | Options > Graphics > Preset. |
| No Man's Sky | Vulkan | planet surface, game start | 18 | The game already picks its lowest quality on this GPU; only a lower resolution scale is left to try. "Hold to select" prompts need a real hold. |
| Slay the Spire | Java | | does not start | The game's bundled Java runtime exits at launch. |
| Hades II | 2D, DX12 | opening scene | 60, flat | A DirectX 12 game that runs. Shows an "Unrecognized Controller" notice at launch; the controller works. |
| Skyrim Special Edition | Creation Engine, DX11 | Helgen, character creation | 29 at Ultra; 38 at Medium; **60 at 720p Medium** | The launcher picks Ultra by itself; choose Medium in its Options and 1280x720 in Steam's game properties. |
| DOOM Eternal | id Tech 7, Vulkan | Hell on Earth, first corridor | 19 to 34 (about 28); 28 at 720p | Default settings. The game's own launcher never starts it; Holodor runs the game executable directly. Its in-game quality preset was not lowered yet. |
| ELDEN RING | DX12 | character creation | 60 | Offline only: Easy Anti-Cheat cannot start, so Holodor launches the game itself (next update). Gameplay not yet measured. |
| Sekiro: Shadows Die Twice | DX11 | prologue well | 28 at default; 45 at 720p; **53 at 720p Low** | The terms-of-use screen must be scrolled to the end before Accept works. Starts in offline mode. |
| Disco Elysium: The Final Cut | Unity, DX11 | Martinaise docks | 27, flat | |
| NieR: Automata | DX11 | opening flight sequence | 18 at High; 21 at Low; 720p not measured | Settings make little difference; the GPU is the limit. Cutscenes and menus 60. |
| Sifu | UE4, DX11 | prologue courtyard | 26, flat | CPU-bound on the render thread. Needs several presses at "Press any button". |
| Fallout: New Vegas | DX9 | Doc Mitchell's house | 60, flat | Easy on the GPU. |
| Death Stranding | Decima, DX12 | first open-world hillside (start of the game) | 17 at default; **28 at 720p Low** | In-game cutscenes run at 60. Options > Graphics Settings: Display Resolution 1280x720, Graphics Quality Low. Rumble works. |
| Clair Obscur: Expedition 33 | UE5 | | runs with `-dx11`, not playable | From the 20261002 release notes. |

Notes:
- Numbers marked "at default" are what the game chose on its own. Most of these games choose their highest settings on this GPU; the second number is the same scene after lowering them, which is what you would play at.
- The 60 fps frame limit was not applied by the gamescope build in the 20261002 image (games ran at 120). The gamescope with the refresh-rate fix from the Retroid Pocket 5 build is going into the next Odin 3 image; the numbers above will be re-measured with it.
- Observer: the crash is Unreal's HTTP thread raising an exception Wine cannot deliver. Adding `[HTTP]` / `bEnableHttp=false` to the game's `Engine.ini` kept it running in testing; a per-game fix is being prepared.
- DOOM (2016): set `+r_renderAPI 1` in the game's launch options before the first start.
- ELDEN RING: Easy Anti-Cheat cannot start, so the game runs offline only. Holodor launches the game's own executable instead of the anti-cheat launcher (from the next update; before that, put `/path/to/eldenring.exe` in place of the launcher by hand).
- Unreal Engine 5 games need `-dx11` in their launch options.
- Audio crackle or distortion in a game (heard in Portal 2 and No Man's Sky): fixed in the next update (the audio buffer is kept at a minimum size). Until then, raise the game's "Audio Buffer" in Pocknix Control.
- Games whose menus want a mouse (Terraria, Subnautica, Fallout 4's launcher) work with the touchscreen.
- Native Linux games: the ARM Steam client has no Linux runtime, so every x86 game runs through Proton.
- Heavy 3D games push the CPU cores to 100 C within minutes with the fan at maximum; expect throttling in long sessions.
