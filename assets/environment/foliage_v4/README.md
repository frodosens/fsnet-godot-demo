# Original foliage v4 — runtime candidates

Four distinct tree species/forms (oak, birch, willow, conifer) and two shrubs (round/tall), made with built-in image_gen, not rotations/recolors of one tree. Oak proof was compared with old v3 at 256 and 96px, then other species were created. Birch/willow/conifer received a targeted image_gen refinement toward broad crisp foliage clusters to reduce initial texture noise. All originals/refinements and prompts preserved.

## Runtime contract

6 RGBA PNGs, 256 square; root-ground pivot [128,240]. Manifest defines visible-height-aware pixel_size rather than using the same sprite size for every silhouette. Some broad sprites occupy less vertical canvas: use manifest pixel_size! Suggested world heights oak 2.6, birch 3.2, willow 2.8, conifer 3.5, round shrub 0.7, tall shrub 1.0. Treat suggestions as starting points, not mandatory scene composition.

Decorative border-only cards; no passability/collision/rules changes. Strong visible species variation must come from selecting different PNGs, not random rotations. Reserve sparse oak for framing, birch for airy transitions, willow near river, narrow darker conifer behind deciduous trees. Avoid uniform rings or rows. Retain walkable-grid readability and avoid hiding units with foreground crowns.

Centered Sprite3D ground pivot needs approximately offset (0,+112), verify engine convention. White base modulation; test nearest/mipmap; alpha-scissor 0.5 is suitable for faint generated edge fringes. Engine lighting must not crush dark foliage into black. Diffuse form shading is authored: these are not normal-mapped relightable 3D trees, and rotating the camera exposes the card limitation. No baked ground plane/shadow.

## Processing and QA

Technical processing only: source crop to alpha>=128 bounds plus 4px margin; actual bottom-foot horizontal anchor from final 12 visible source rows; aspect-preserving nearest resize; transparent canvas alignment. No code-painted pixels or synthetic tree art. Original alpha preserved. Manifest hashes runtime PNGs. Full 256 and 96px dark-background contact sheet inspected, plus original-v3/oak comparison. All six images have true alpha. Actual target-camera capture, material values, silhouette overlap, mip shimmer and shadow-card rejection remain engineering acceptance tasks.
