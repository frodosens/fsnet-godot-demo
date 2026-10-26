# Character scale, status artwork, and continuous route preview

This is an interactive fixed-background presentation increment, not a claim of pixel-identical concept reproduction or complete background collision-art acceptance.

## Scale diagnosis and correction

Baseline: `1da310bb590b7841c7af4a5e2b652d60fd0139e3`. Reference viewport: 1280×800, orthographic camera, 45° elevation. A unit grid tile projects to basis (+47.94,+33.90) / (-47.94,+33.90), so depth does not make distant actors smaller.

Standard front-right idle opaque-alpha bounds yield approximately 52–60 screen pixels of character height at pixel_size 0.01125 (97–111 source pixels, 1.09–1.25 world units). Fixed-background mode now uses a separate 1.25 multiplier: approximately 65–75 pixels / 1.36–1.56 world units. Other facings have slightly different silhouettes. Original 3D mode remains at 1.0.

Manual image measurements, with ±5 px uncertainty: near lamp finial-to-ground is approximately 98 px; inn doorway opening approximately 65 px. The lamp/actor ratio drops from approximately 1.6–1.9 to 1.3–1.5. A street lamp can legitimately be taller than an adult. The painted door and lamp are themselves not perfectly consistent: continuing to enlarge every actor would make the door mismatch worse. No background pixels, grid coordinates, movement costs, collision, or rule state were changed. A local doorway art correction is a remaining option, not silently implemented.

The scale configuration is `assets/backgrounds/amber_bridge/presentation.json`. Sprite center height uses the authored ground anchor (48,120); badge/ghost/contact footprint and gait stride follow the scale. Switching back restores the original scale. Gait phase remains distance-driven. Existing four-frame support-foot residual drift is not eliminated by this scale change; it must not be described as zero skating.

## Status-bar comparison

`status-reference-before-after.jpg` is explicitly a comparison: left is the approved concept, center the old runtime, right the new runtime. Crops have been resized uniformly for equal display size; no scene content was retouched. Full-screen captures remain separate.

Changes: remove transparent delivery padding through an AtlasTexture view (source images unchanged); retain portrait aspect; separate 24px name from subdued 16px profession; strengthen existing raster HP/MP frame/fill at small display sizes; use the authored diamond texture around action glyphs; retain real dynamic values; add a soft local fade over busy background foliage, without an opaque rectangular panel. Two companion portraits, native labels, and real meter clipping remain functional.

Remaining visual differences: original portrait designs and frame ornaments are not identical to concept characters; the current HP fill is textured gold rather than the concept's flatter pale fill; the background foliage is brighter/busier than the concept. This increment is not labelled 1:1.

## Continuous path arrow

The preview consumes only the existing Lua BFS path. Corners are quadratic rounded segments with a 0.20-cell radius inside the turn cell, with shared ribbon vertices and one terminal arrowhead. There are no detached per-cell arrow sprites. Hover changes reveal from the common prefix; invalid/cancel/commit clears the route. No interpolation is performed across unrelated paths or blocked cells. A subtle travelling highlight follows the same curve. Reduced-motion disables reveal/flow.

The mesh stays on the depth-tested ground plane, below opaque character pixels. Width is expressed in logical screen pixels and unprojected onto the ground, retaining the project's UI scaling policy. Actual movement continues to consume the unmodified authoritative cell path; rounded visual corners are not new rule waypoints.

`runtime-video/continuous-route-arrow.mp4`: real 1280×800 Godot capture, 30 FPS movie mode, mouse hover over four destinations, one click, automatic three-cell movement to the bridge, exactly one shared command step. The video is visual evidence, not a hardware performance benchmark.

## Verification

- `tools/test.sh`: 1,308 reported assertions, zero failures; four actual fsnet server/two-client/reconnect scenarios passed. Complete output: `scale-status-route-test-results.txt`.
- `test_route_ribbon.gd`: 39 checks include one-cell/straight/turn/reversal geometry, containment within authorised cells, rapid change, cancellation, invalid destination, reduced motion, and unchanged rule snapshot.
- Fixed-background adapter: 694 checks across seven viewport shapes, including unchanged grid picking, light anchors, scale/ground-anchor consistency, restore-to-3D, and legacy-map rejection.
- Real GPU test: 24 combinations (six roles × 3D/fixed × 960×600/1280×800), 10,492 opaque-body samples unchanged with synthetic all-ground overlay enabled. This is a rendering stress fixture, not a claim that every tile is walkable.
- Actual full-size captures at 960×600, 1280×800, 1920×1080; same rendering state, not resized screenshots. PNG originals are retained locally; repository JPEGs are full-resolution delivery conversions.
- Godot 4.6.3, Linux, OpenGL Compatibility, Mesa llvmpipe. No physical Android device validation.

## Remaining gates

The six original fixed-background bank-edge visual conflicts remain: (6,2), (7,2), (8,2), (9,2), (0,6), (1,6). No walkability changes conceal them. Background bank correction and full first-chapter visual traversal acceptance remain outstanding. Fixed mode uses contact shadows and local real character lighting, not full baked-image dynamic shadow receiving or sprite normal maps. Android preparation remains paused; no SDK/NDK/license changes are part of this commit.
