# Camera-facing map character candidate

Isolated review branch, not main. Only map presentation changes; battle side-view
art, source PNGs, shared rules, actor IDs/facing, commands and RNG are untouched.

The old FIXED_Y billboard projected the vertical dimension of already-painted
isometric art a second time (~0.707 at this camera). Increasing its uniform size
also widened the art. Formal map sprites now use full camera-facing billboards,
with local pixel offset (0,56) placing texture pivot (48,120) at the Sprite3D node
origin on the ground. Uniform base pixel size 0.010727272727 preserves aspect ratio.
The reference scene retains its 1.25 scale: a 99-source-pixel figure projects to
90 logical pixels at 1280x800; exact silhouette heights vary by role/direction.
960x600 scales this naturally rather than fixing a 90 physical-pixel billboard.
Original 3D uses its existing 1.0 scene scale and normal depth-tested geometry.

`figure_pixel_position` defines the camera-plane mapping for head bars and tests.
Badge, healing number and destination ghost anchors use this model. Contact shadows
stay on world ground cells, not sprite centers. Shaded texture-colored emission and
local lights remain active. No nonuniform stretching, body bob or compensating source
warps. Procedural fallback figures retain their previous vertical behavior.

Validation on Linux Godot 4.6.3 / Mesa llvmpipe:
- 141 projection-specific checks: six roles, both renderers, 1280x800/960x600,
  source-axis equal scale, exact foot anchor, shadow lifecycle and custom-map fallback.
- Full suite: 4502 checks + five real three-process network/reconnect cases.
- Actual captures of both renderers at both sizes inspected. Comparing range off/on
  at 30,625 opaque interior actor sample pixels found zero changed pixels.
- Painted lights on/off visibly affect nearby actors (Oren 1655 sampled pixels,
  mean maximum RGB-channel difference ~12.9); distant Mara remains unaffected.
- Fixed contact-shadow on/off changes 2924 screen pixels. A separate 3D occluder
  fixture changes 2535 pixels and covers the character, confirming depth remains
  enabled. These bounded checks do not prove every possible building/camera layout.
- The old diagnostic's removed-shadow-array access is eliminated: fixed shadows are
  only indexed while active; original 3D explicitly checks the array is empty.

Limitations: fixed painted background still has no foreground occlusion mask; baked
buildings cannot dynamically cover a character without a dedicated mask/geometry.
Current world geometry in 3D can occlude units (including the existing nearby lamp).
Larger silhouettes overlap more when adjacent; no rule/grid positions were moved.
Mara candidate retains its documented approximately one-source-pixel foot variation
and old/new idle transition pop. Battle idle is still single-frame. Windows visuals
have not been tested here. Review captures/video remain local/Library, never Git.
