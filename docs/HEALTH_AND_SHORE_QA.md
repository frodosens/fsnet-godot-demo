# Overhead HP visibility and shoreline v5 acceptance

## Walk diagnosis remains open

Actual video `continuous-route-arrow.mp4` moves Mara from (4,7) to (4,4): **back_right**, not front_right. `mara-back-right-runtime-four-frames.jpg` contains actual movie frames 114/118/122/126, cropped at the same rectangle and nearest-neighbour enlarged. It is not a manufactured animation. Separate source contact sheets show both directions. Back-right 00/01/03 retain a strongly inward-bent near leg, and front-right 00/02 have excessive strides/outward boot tips. Runtime applies uniform scale, fixed registration, and distance-driven phase; it does not shear limbs, rotate ankles, recenter each frame, or add body compensation.

No walking artwork was replaced in this increment. A separately authorised Mara-only layered/IK prototype is in preparation. No claim of fixed gait or zero foot sliding is made.

## Overhead meters

Old world-space meters rendered around 3 px high at the reference viewport. New meters use existing authored HP frame/fill, a dark backing, and a physical minimum of 54×8 px. Selected/recently damaged meters receive a modest size/brightness emphasis; damage emphasis expires after 0.45 seconds. Full-health units retain meters; dead units hide them. Fill derives from clamped real HP/max HP, not presentation timers.

Allies carry a diamond and enemies a triangle, in addition to distinct tint. The marker and meter remain unshaded/readable and depth-tested. Coplanar fill/frame z-fighting is avoided by small camera-axis depth separation. Their world anchor is lowered toward the head, retaining a margin above the opaque silhouette. Tests verify at least one physical pixel of head clearance for the six current poses across both renderers and three windows.

`health-meter-before-after.jpg` is a real screenshot crop comparison. The background also changed from v2 to v5, so it is not an isolated background-invariant experiment.

## Shoreline asset

Art source: `fa443d2954bcce65b186cb108d6241a358d4bf5a`; locally integrated as `ea13a17`. Runtime PNG verified with Pillow and SHA-256 `aa810fdbea840ca90d5a4d6700de4b64d0c944588accc0cc2e98352d964fb5ab`, 1,960,155 bytes. v2 remains recoverable from git history.

Twelve actual legal move commands were accepted by the unchanged shared rules: the six repaired cells (6,2), (7,2), (8,2), (9,2), (0,6), (1,6), and all six bridge cells x=4/5, y=3/4/5. These are explicitly isolated spawn fixtures; production unit positions and map data were not changed. The resulting screenshots confirm feet on grass/deck. `shore-v5-twelve-footpoints.jpg` is a crop sheet of those real rendered fixture endpoints.

This closes the former **foot-center** conflicts, not every whole-cell-corner/foreground-occlusion issue. Some peripheral tile corners still extend near water/decorations; painted railings do not provide a full dynamic foreground mask. The fixture does not substitute for a complete uninterrupted first-chapter visual playthrough.

Four lamp/window patches were compared against v2 using a 17×17 RGB template with ±8 px search. All best displacement estimates were (0,0); pixel colours differ, so this is approximate position evidence, not an assertion of identical image content. Light anchors remain unchanged; their background hash is updated. Results: `shore-light-anchor-check.json`.

## Validation

- Full suite: 1,428 checks, zero failures, plus four real fsnet server/two-client/reconnect scenarios; `health-shore-test-results.txt`.
- Meter-specific: 120 checks including three actual window sizes in the projection model, six units, both renderers, physical size floor, opaque-head clearance, faction shape, half/full/dead HP, short damage emphasis, and unchanged snapshot.
- Real rendered 960×600, 1280×800, 1920×1080 screenshots in both original 3D and fixed-background modes. No resized window screenshots used as resolution evidence.
- Linux Godot 4.6.3, OpenGL Compatibility, llvmpipe; no device/Android performance claims.

Original Android preparation drafts remain outside this commit. No new dependencies were installed.
