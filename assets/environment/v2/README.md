# Amber Bridge environment v2 — prototype albedo candidates

Eight original built-in image_gen outputs, generated 2026-10-26 for the approved restrained, low-saturation pixel village style. This is an asset-only handoff, not a rendered-game acceptance or near-release art claim.

## Runtime files

Copy `textures/*.png` to `assets/environment/v2/`. Each is 256×256 RGB PNG, sampled at 128×128 then enlarged nearest-neighbor. Sources remain byte-for-byte in `sources/`; `generation.json` records complete prompts. No programmatic painting, edge blending, generated normals, stock art or scene paintings were used. Conversion/resizing and QA montage composition only.

- grass: muted olive ground; dense micro-clusters remain, assess moire at actual tactical camera scale.
- earth: compact pebbled earth/path, also suitable exposed earth sides.
- stone_paving: bridge deck/top; approximately five slabs per unit.
- stone_masonry: bridge sides/rails and foundation; repeat seam still moderately detectable along horizontal mortar boundary. Candidate, not perfect seamless certification.
- plaster: wall infill, with separate timber geometry; no baked beams/windows.
- timber: beam/door wood, grain along texture V.
- roof: flat muted terracotta tile pattern, U across eave and V down slope. Flat-roof geometry will still look flat; this does not provide a pitched silhouette.
- water: opaque flat slate river albedo. Ripples are color marks, not lighting/reflection/animation or a water shader.

## Integration contract

Start with one repeat per world unit for terrain, masonry and plaster. Use dimension-aware planar UVs on faces rather than BoxMesh's multi-face atlas default; avoid stretching a full square across a 0.12-wide rail. Texture repeat enabled, sRGB albedo, roughness around 0.9, metallic 0. No normal map. Start nearest sampling; test nearest-with-mipmaps at gameplay camera to reduce fine-pattern shimmer. Do not tint these by the old terrain albedo colors: white material base color, then restrained separate selection highlight modulation. Current main.gd refresh replaces albedo_color, so integration must explicitly account for this.

Textures were inspected as 3×3 repeats (all eight). Seam metrics in qa/seam_metrics.json measure opposite-edge RGB difference against internal adjacent-pixel difference; they are diagnostic, NOT proof of seamlessness. Not all opposite pixels match. Paving/masonry show stronger Y-boundary steps; use actual-scale testing before acceptance. Roof v1 was discarded for obvious row seam and baked shading, and regenerated. New roof has flat color tiles and no directional shading.

## Acceptance still needed

Real Godot screenshots at target camera, per-face UV orientation, no dark multiplier, legible movement highlights, roof/bridge geometry silhouettes, temporal shimmer, and water readability. No game code modified or runtime tested in this task. Publication target is the asset-only art/environment-v2 branch; main remains untouched by this asset task. Initial branch creation was blocked, then authorized by the parent supplying the prior explicit public-project push permission.

## Runtime naming
Engineering names: `dirt.png` = earth, `stone_wall.png` = stone_masonry, `wood.png` = timber. Source filenames and QA labels retain generation names. Runtime PNGs are directly under assets/environment/v2 in Git, but in the textures subfolder of this archive.
