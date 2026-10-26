# Ground overlays, character emission and painted-lamp lighting

Actual Godot 4.6.3/OpenGL captures at1280×800, following a497654. Background image and gameplay data are unchanged.

## Ground-layer bug fixed

The old `view/path_preview.gd` drew range outlines/path/arrows in the HUD CanvasLayer, above all 3D characters. It now creates depth-tested ground triangles at y=0.025. Screen-sized strokes are unprojected onto that plane; the route still uses the same Lua BFS path. Range fills remain ground planes. Opaque/discard character pixels write depth, so ground lines/fills cannot paint over bodies. No transparency reduction workaround. Ground preview is retained by both renderers; ghost preview is separate. HUD remains above the world.

Actual GPU stress test `tests/test_ground_overlay_render.gd`: all6roles × original3D/fixed ×960×600/1280×800. Deliberately forced coverage on all tiles is a rendering fixture, not an expanded legal movement range. Comparing ground overlays on/off gives zero changed pixels in10,492 sampled opaque-interior body locations. Sampling excludes alpha edges. Detailed24case results in `ground-overlay-render-results.json`. Actual gameplay screenshot: [fixed-background range beneath actors](ground-layer-fixed-runtime.jpg), [original3D](ground-layer-3d-runtime.jpg).

## Character-colored emission

`view/lit_character.gd` keeps shaded Sprite3D material, alpha scissor, nearest texture filtering and current animation texture. Emission is the actual texture color multiplied by0.35, not white wash or bloom. Pause menu has a0–0.6 character-fill slider; it is a session presentation preference and does not change rules/save snapshots. Original3D and fixed-background use the same actor material. Walk/idle changes update both albedo and emission textures together.

Lambert-wrap diffuse response intentionally gives flat cards a broad response to nearby lights; standard one-sided Lambert left the nearby lamp behind the camera-facing card with almost no visible effect. This is stylized lighting, not a normal-map simulation. Near-view combat already draws full-color CanvasItem textures; no second boost was added. Its victim-only white-flash shader/reset remains independent, with GPU `FLASH_GPU_PASS`.

Same-state emission comparisons: [fixed emission on](ground-layer-fixed-runtime.jpg) / [off](character-emission-off.jpg); [3D on](ground-layer-3d-runtime.jpg) / [off](character-emission-3d-off.jpg). These are unretouched full-resolution JPEG exports of the original PNG captures.

## True local lights at painted lamps

`assets/backgrounds/amber_bridge/lights.json` records original-image pixel anchors, heights, colors, energy, range and attenuation: near lantern(329,256), far lantern(1025,188), inn window(107,224), inn door(157,235). Four actual OmniLight3D nodes use the same inverse projection, with a dedicated character-layer mask. The image plate remains unlit/baked. Existing3D Omni lights are hidden in fixed mode and restored on exit; no accumulating permanent lights. Seven resolution tests verify anchor projection and four-light count.

[Local lights on](painted-lamps-on.jpg) / [off](painted-lamps-off.jpg) keep sunlight, ambient and emission identical. Mara reaches safe dirt cell(1,7) via a real3-cell command, about1.23world units from the near lamp; Oren remains about1.54units from the far lamp. Direct comparison changes1,037pixels around near-lamp Mara and1,177around far-lamp Oren, maximum RGB channel differences32/38 respectively. No painted-background pixels are brightened. The intrinsic Omni attenuation is smooth; the two screenshots are not a time-sampled attenuation benchmark. Lamp cast shadows remain disabled; existing independent contact shadows are preserved.

## Verification / remaining limits

Full suite:1261 counted checks and all4actual fsnet three-process/reconnect cases passed. Additional GPU overlay test24cases passed; victim-only flash GPU test passed. Rule snapshots remain unaffected by renderer, fill slider and light toggles. Physical pixel comparisons are in `character-lighting-pixel-results.json`; exact runtime lamp positions are in `painted-light-anchors-runtime.json`.

Six bank-edge image caveats remain; no rule cells were changed or hidden to mask them. No foreground occlusion image, fully directional character shadow or arbitrary-camera support is claimed. Character/source art and busy HUD background still need artistic review. Android remains paused, with unrelated local drafts excluded from this commit.
