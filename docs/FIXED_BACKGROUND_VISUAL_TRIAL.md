# Fixed-background v2 — actual visual trial

2026-10-26. The painted asset now loads and has been rendered in Godot 4.6.3, OpenGL Compatibility, Mesa llvmpipe at1280×800. These are real game screenshots, not the source concept with pasted characters.

- [Painted background + lit characters + contact shadows](fixed-background-runtime.jpg) — full-resolution JPEG745,581bytes, no image retouch/crop. Original PNG preserved alongside.
- [Same state, direct character lights disabled](fixed-background-character-light-off.jpg) — ambient remains; background baked lighting is unchanged.
- [Same state in original 3D](fixed-background-3d-comparison.jpg).

Mara reached bridge cell(4,4) through a real shared Lua move from(4,7); presentation was settled before capture. No positions/terrain were secretly changed to fit the painting. Six independent contact shadows are rendered and follow characters; these are soft 2.5D contact planes, not full directional cast shadows. Existing character Sprite3D lighting is active, without normal maps. The direct-light-off capture changes8,383pixels above a one-level threshold, concentrated in foreground actors; there is no whole-background relighting filter. State snapshot is unchanged across the renderer/light toggles.

## Important limitations visible in this trial

- Six bank cells remain artist-reported caveats: (6,2),(7,2),(8,2),(9,2),(0,6),(1,6). This is not full-map playability acceptance. Bram's unchanged starting cell(7,2) is among those locations; this was not concealed by relocating him. The movement demonstration stays on the central bridge route.
- Characters currently appear darker than the painted surroundings. Direct/ambient balance needs art calibration; the light-off comparison proves independence but does not certify a finished lighting match.
- Right-side and lower-border vegetation is busy behind HUD text. Readability/quiet-area work remains.
- No foreground occlusion layer is supplied. Painted rail/vegetation depth cannot occlude characters correctly for arbitrary interactions. No arbitrary camera rotation.
- Original 3D remains the default. Pause → scene button toggles this explicitly experimental background; terrain compatibility is checked. User Mod terrain is not rewritten.

## File integrity / checks

The first transferred art blob was corrupt (IDAT CRC failure). Fixed upstream commit35fb2bf restores the original2,124,419-byte PNG; SHA256 `1bbb8d93bd390f726adba0cf762c5624e21b143ce97ccdaf2d8cec81b76c3cb1`, Git blob `1ee80ae8c04ae01b3a0e83fbc8d452e96f032ea9`. Pillow verifies and Godot imports successfully. Only this asset's known failed generated import record/cache was removed to clear its stale `valid=false`; no other work was cleaned/reset. Normal runtime availability now requires a loadable1280×800 texture, not file presence alone.

Post-integration targeted checks:651 adapter assertions and11 movement-event assertions passed; actual OpenGL capture completed with six shadows and unchanged snapshot. The preceding adapter full regression remains1201checks/four real network/reconnect scenarios; it is not relabeled as a newly repeated full run after this asset-only integration. `fixed-background-visual-results.json` records screenshot SHA256 and light-toggle pixel statistics.
