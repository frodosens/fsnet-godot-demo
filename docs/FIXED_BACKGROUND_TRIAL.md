# Reversible fixed-background trial — engineering stage

Scope: only the authored `amber_bridge_reference` terrain. No replacement of shared Lua, commands, deterministic state, network, saves or Mod editor. Other/modified terrain retains the existing 3D renderer.

## Art contract

`docs/fixed-background-contract.json` contains all 90 cells with centers/corners and terrain, bridge/river intervals, starting character feet, reserved UI regions. `fixed-background-geometry-guide.png` is a technical color-block guide, not game art. Canvas 1280×800. Approximate affine mapping: origin (683.83,64.41), +X (47.94,33.90), +Z (-47.94,33.90). Runtime uses the exact existing Camera3D matrix, not rounded affine numbers.

Runtime resources: `assets/backgrounds/amber_bridge/background.png`, optional transparent `foreground.png`, both 1280×800. No baked people/UI/text/grid. Foreground is an optional border occlusion layer; it cannot simply cover the whole walkable area. No asset exists at these paths yet in this engineering commit.

## Display and lighting

`view/fixed_background.gd` hides original static geometry reversibly, retaining independent Sprite3D characters, existing lights, grid range overlays, shared BFS path, target ghost and HUD. Background is a camera-aligned unlit image plate behind the world; optional foreground is a transparent plate ahead of the world but below HUD. No arbitrary full-camera rotation is supported by the painted scene.

The image is uniformly contained in the viewport. Wide or tall windows use side/top-bottom bars rather than stretching/cropping; UI remains separately anchored. Camera sizing changes reversibly to keep all projected cells aligned. Clicks in letterbox areas are rejected. Pause menu enables switching only when matching art exists; default is still original 3D.

Characters retain existing directional/Omni illumination. Six independent soft contact-shadow planes follow actual interpolated feet and settle after skip. This is an explicit 2.5D contact shadow, **not** a full dynamic directional cast shadow or a claim that a painted image receives arbitrary world shadows. Background environmental light is baked; current sprites lack authored normal maps. Foreground masking, painted bridge edges and lighting consistency must be visually accepted with the real image.

## Verified so far

- 651 adapter checks across actual Window sizing configurations: 960×600, 1280×720, 1280×800, 1920×1080, 2560×1440, 2560×1080, 1280×1024. All 90 centers pick back to the correct grid cell; maximum contract-coordinate error <0.007 logical px. Includes letterbox input rejection, interpolated shadow follow, skip/settle, restoring 3D and rejecting legacy terrain.
- Full existing regression plus adapter: 1201 counted checks, four real fsnet three-process/reconnect scenarios passed.
- Actual OpenGL/Mesa llvmpipe render with explicitly synthetic geometry-guide fixture: shader compilation, image orientation/projection, lit independent characters, six visible contact shadows and unchanged state verified. The temporary `/tmp/amber-fixed-guide-runtime.png` is not a final art screenshot and is not presented as one.

`tests/capture_fixed_background.gd` captures original 3D and final painted version in identical state once real art exists, then an additional direct-lights-off comparison. `--fixture-guide` is engineering-only, outputs under `/tmp`, and never substitutes a fake background in normal play. No final painted-art acceptance or device-performance claim yet.

## Foot-drift note

The artist's foot annotation commit 0bdd15f is retained. Its camera annotation predates the current 45° azimuth: current +X screen slope is 0.707106, not 0.445910. Using manually annotated support points with ±2px uncertainty, fixed-Y billboard projection and current 0.5 stride, 00→01 endpoint drift is approximately (-1.63,+3.16)px, magnitude3.56px; 02→03 is (-4.69,+4.24)px, magnitude6.32px at1280×800. Separate optimal strides0.467/0.594 still leave3.52/6.16px residual. These are endpoint estimates, not a full held-frame foot-lock analysis. No speculative sprite-root compensation was added; painted-background trial takes priority.
