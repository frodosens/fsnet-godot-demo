# Amber Bridge border props v3

Original built-in image_gen props following the approved HUD v3 map target. Five transparent 256×256 RGBA cards, not 3D meshes or scenic backgrounds. Original outputs preserved in sources. No ground plane or baked ground shadow. Diffuse form shading remains authored; there is no relightable normal map.

## Integration

Runtime path assets/environment/props_v3. Names: tree, shrub, reeds_rocks, supplies, lantern. Manifest declares fixed ground pivot [128,240], actual alpha bounding box and pixel_size for suggested visible world heights (2.5, 0.7, 0.8, 0.9, 1.5). For centered Sprite3D, offset the texture so that this pivot coincides with node origin; expected offset (0,+112), verify Y sign in engine. Use Y-axis billboard for fixed tactical camera and test with camera elevation. Tree/shrub silhouettes are intentionally original and asymmetrical.

Nearest or nearest+mipmap sampling; white modulation, rough diffuse shaded cards, alpha scissor around 0.5 (generation includes faint alpha fringes). Test shadow casting; never accept opaque card-rectangle shadows. Place outside walkable cells and keep tactical silhouettes/picking unobstructed. Lantern glass amber is authored small color, not an actual light source; engine may add a restrained light separately.

## Processing and QA

Built-in image_gen only for artwork. Allowed technical processing: crop to alpha>=128 visible bounds plus 6px margin, nearest aspect-preserving resize, paste into transparent canvas aligned to ground pivot. No programmatic painted art, no alpha repaint or relighting. Sources kept byte-for-byte. Generation prompts in generation.json. Manifest SHA256 covers runtime images. Visually inspected all five on dark background; alpha ranges checked as 0..255. Some original outputs contain nearly invisible fringe pixels far beyond the visible prop; crop and engine scissor handle them. Runtime silhouettes have no visible rectangular ground backdrop.

Actual engine camera scale, occlusion, alpha-scissor edges, shadow behavior and visual consistency remain acceptance checks. This is a small border dressing set, not full-map completion.
