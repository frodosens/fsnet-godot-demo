# Mara back-right: continuous layered walk proof

Scope is deliberately one character and one direction. Other directions/characters keep their existing art. The original source frames remain intact. The optional pause-menu switch `玛拉右后分层步态样板（小步）` defaults off. This is a first-look prototype, not final animation acceptance.

## Source and composition

Seven authored 96×128 RGBA layers from art commit `ee8721c85b7138bde2eaecf629f068254df13600` are integrated under `assets/sprites/layered/knight/back_right/`. All seven file SHA-256 values match their manifest. Full-canvas registration and ground anchor (48,120) are preserved. The manifest supplies hip/knee/ankle/estimated sole points, draw order, and near/far identity.

`view/mara_layer_rig.gd` draws independent thigh/shin/boot layers through continuous two-bone IK into a transparent 96×128 SubViewport. Its texture feeds the existing lit/emissive Sprite3D, retaining billboard orientation, ground contact shadow, and map layering. Boots keep their authored angle instead of inheriting shin rotation. Bones are rotated, never stretched or sheared. Source textures are not repainted.

The neutral legs are nearly fully extended. The walk posture therefore uses a **constant** 2-pixel pelvis/upper-body lowering, not per-frame body bobbing. Base stride is 0.09 world units/cycle, multiplied by the fixed-view 1.25 character scale; stance fraction 0.60 and swing lift 2 source pixels. This is intentionally a short-step contact proof. Larger production strides need separate visual/reach acceptance. The boots' authored axis and movement projection still differ; the prototype does not hide that with shear.

Support-foot targets compensate the body's projected travel. Swing uses a continuous Hermite trajectory, with contact-relative velocity at both ends and a smooth squared-sine lift. Joint targets outside reach are explicitly measured; no hidden limb scaling is allowed. Fixed-scene projection and the original 3D camera are evaluated through the current camera, not a hardcoded screen slope.

## Actual evidence

- `runtime-video/mara-layer-rig-before-after.mp4`: 344 actual Godot frames at 30 FPS, 11.47 seconds. Old then new, same scene, same legal move (4,7)→(4,6), same world translation speed (0.225 units/s), same camera. The old animation playback multiplier is 0.18 to match the deliberately slow new short-step proof; this is documented rather than disguised as normal gameplay speed.
- `runtime-video/mara-layer-rig-closeup.mp4`: nearest-neighbour crop/enlargement of that same video, not separately generated animation. First half old, second half new.
- New clip: 134 moving frames, zero reach-clamped frames, maximum reach error 0.0 source pixels. Both clips execute one real shared-Lua movement command; presentation does not alter the resulting snapshot.
- `mara-continuous-rig-phases.jpg`: eight GPU-rendered **2D composite** phases, not eight source frames or a claim of 3D lighting. `mara-rig-lit-runtime.jpg` is the separate real in-world lighting capture.
- Same-pose light-on/off comparison in the Mara region changed 1,313 pixels, max channel delta 107; emission was retained. `mara-rig-light-response.json` records the crop and caveat.

## Tests and limits

Full regression: 1,621 reported checks and four actual fsnet server/two-client/reconnect scenarios passed. `mara-rig-test-results.txt` contains the output. Additionally, 401 real-asset phase samples produced zero reach clamps; ideal sole-marker support drift was approximately 0.000004 source pixels. This is a numerical marker result, **not measured zero raster foot sliding**: authored sole estimates carry ±1.5 px uncertainty and nearest-neighbour rasterization is quantized.

193 synthetic-joint checks cover fixed bone lengths, unreachable-target reporting, unchanged boot rotation, support-foot cancellation, and cycle continuity. The real-asset lifecycle test confirms skip restores the ordinary idle texture, disables the temporary viewport, and preserves the rule snapshot. Switching to unsupported directions falls back to original frames.

Remaining: user visual review; silhouette/joint-seam refinement if needed; longer stride and more natural pace; transitions and idle blending; other three Mara directions; all other characters. No complete six-character animation claim is made.

## Overhead HP follow-up

Only world-space meters changed: backing margin reduced from 2 to 1 physical pixel per side, fill height increased 30% while staying within the frame, total bounding height reduced. Left-bottom status UI is unchanged. Near-face avoidance is bounded to one horizontal displacement, avoiding bars drifting multiple tiles away. The final bounded face-avoidance tweak was followed by a 120-check focused health rerun and fresh 960/1280 captures. Dense overlaps remain a presentation tradeoff; this is not a general label-layout solver. Full/dead/damage rules remain unchanged. `health-thinner-border-comparison.jpg` shows same-HP real captures at 960×600 and 1280×800; crop enlargement is for inspection, not resolution-test evidence.
