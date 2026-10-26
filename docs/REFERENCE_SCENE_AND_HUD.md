# Reference scene + raster HUD integration — 2026-10-26

This increment is an interactive Godot scene, not the concept image pasted behind an interface. It is closer to the approved reference but not pixel-identical.

[Same-aspect comparison](reference-hud-comparison.jpg) · [50% overlay for QA only, not a runtime background](reference-hud-overlay.jpg) · [Actual 1920×1080 screenshot](reference-hud-1920x1080.png)

## Play the new scene

New Game starts `content/reference_bridge.json` (`amber_bridge_reference`). Network content selection offers the new scene and the original bridge. `content/default.json` is unchanged and remains the regression fixture; existing saves embed their own validated content and are not overwritten or silently migrated. Reserved built-in IDs cannot be overwritten through the Mod writer.

The new map is 10×9, with three river/bridge rows rather than two. Mara begins at (4,7); the demonstrated three-step destination is (4,4). Unused perimeter forest cells are explicit X obstacles, not hidden decorative collision. The six characters, original story, victory and defeat predicates remain unchanged. Old and new content hashes differ and a network mismatch is rejected.

For command-line network play of the new scene, set `AMBER_MOD` to the absolute path of `content/reference_bridge.json` in **both server and client environments**, plus the same private `AMBER_TOKEN`. The graphical host/join menu passes the selected content directly. Invalid command-line content now reports an error instead of opening an unrelated battle.

## Actual geometry changes

- Three-row bridge; deeper visible water (-1.15), curved side supports and twelve individual wedge-shaped arch stones per exposed side.
- Three courses of offset bank stone; small ruin stones around explicit blocked forest cells.
- Separate inn porch roof/posts/braces, steps, hanging wooden tankard sign, window shutters/mullions, door planks/hinges, roof verge beams/ridge and individual edge tiles. Existing legal materials are reused.
- Denser boundary undergrowth and trees; built-in forest obstacles agree with Lua traversability. Tree sources still repeat—this is not a set of newly painted unique trees.
- Camera azimuth is now 45° with 45° elevation, preserving the same four diagonal facing identities. The obsolete flat-cardinal camera assertion was replaced by the actual iso4 contract and the four-direction movement tests still pass.

## Real artwork in the HUD

Integrated art commit `4e24f94f09a29d9e010f7a4f4e4550efeffe0c40` (local cherry-pick `30e8094`): 16 original PNG components. HP/MP fill is a TextureProgressBar clipping the authored texture at the real value; frame is a separate overlay. No flat programmatic progress rectangle remains in these status meters. Heart/crystal, boot/action, command icons, selected/unselected diamonds and portrait frames are real raster assets. Values and translated text remain native.

The selected portrait is no longer duplicated among teammates. The large dark status rectangle is removed. Commands remain visible during movement preview. Selection/focus uses a cancellable 120ms scale/lift/text-color transition; repeated changes kill the previous Tween. Disabled controls settle without activation; keyboard focus has a separate pointer.

Anchors (logical viewport fractions): portrait top-left (.02,.80), extent (.085,.16); companion centers (.135,.80), (.175,.80); command centers x=.88 and y=.31/.41/.50/.59. [Measured positions](reference-hud-anchor-measurements.json) include actual/target coordinates and errors. Command widget-center error is below 0.1 logical px; companion rounding stays below 2 logical px. The intentional selected-icon lift is 2 logical px and is not an anchor error. Transparent asset padding is not claimed to match every reference pixel.

## Movement is one destination click

`tests/test_move_interaction.gd` sends actual input events through the scene handlers:

1. Click a player unit to select it; choose Move.
2. The legal range comes from Lua BFS, clipped by terrain/units; hover previews the same path.
3. One destination click, including without prior hover, issues one command containing the full path.
4. The character walks every path segment automatically; clicking again during motion cannot submit a second command.
5. After arrival the action menu returns with the spent move disabled.

Right-click/Escape cancel without a command, action cost or RNG advance. Invalid targets retain an explanatory hint (fixed a refresh that erased it). Dedicated input test: **11 checks pass**, exactly one move at step 1, path `(4,7) → (4,6) → (4,5) → (4,4)`.

[9.1-second actual interaction recording](runtime-video/reference-hud-selection.mp4): starts with Mara already selected; keyboard Attack/Move at ~1.3–2.9s, actual GUI mouse hover/click at ~2.9–4.6s, shared path preview ~4.6–5.6s, one destination click at ~5.6s, automatic three-segment walk and disabled move until ~9.1s. The selected-unit click is separately covered by the input test. No claim of mobile touch-device acceptance; the desktop no-hover click path is verified.

## Verification

- Complete regression run: **509 counted checks**, scene input and four separate fsnet three-process network/reconnect scenarios pass; an additional selected-unit input assertion brings that focused suite from 10 to 11 passing checks.
- New content: 44 checks, complete greedy battle reaches victory; passive player reaches defeat; three VM hashes agree; snapshot/tail replay and cross-map save/load restore the right embedded map and local dialogue cursor.
- New map real-network step-3 hash: `3ca3d5f01e1ea36b0cfc837f45e08897c431bde821fb269a71ef0e2947595939` on both clients after reconnect.
- Raster HUD: actual X11 rendered and anchor-tested at 960×600, 1920×1080 and 2560×1080. Earlier six-size layout matrix is retained; the other three sizes have not been rerendered after this latest component swap.
- Godot 4.6.3, OpenGL Compatibility, Mesa llvmpipe. The 273-frame video is fixed-30-FPS offline MovieMaker output, took about 50 seconds to render and is **not** a real-time performance benchmark. It is silent; no new movement sound is claimed.

## Remaining visual differences

The inn/bridge silhouette and layout are substantially changed, but surface weathering, vegetation variety, shoreline breakup, water reflection and some sprite animation poses still differ from the concept. Artwork-specific typography/spacing and the rest of the HUD (especially chapter title/turn banner) are not a pixel-for-pixel reconstruction. The prototype still needs human visual acceptance and hardware GPU/platform validation. The concept remains a reference artifact, not runtime scenery.
