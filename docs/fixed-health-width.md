# Fixed map health-bar width

Map health bars use a fixed base width of **50 logical pixels**, scaled by the viewport pixel ratio and scene magnification (the adapter's original camera height divided by the current visible world height). This follows mobile cover and orthographic zoom without measuring art. Actor-specific scale, facing, animation, experimental options, and role do not change the base width. The existing thin frame, HP fill, damage/selection feedback, world anchor and opt-in face avoidance remain intact. The explicit base-50 choice supersedes the former body-width cap: narrow standard/reserve poses or custom Mod art may be narrower than the bar. Crowded units can overlap bars while avoidance is off; the existing local opt-in remains available.

This replaces runtime per-texture silhouette measurement. No image reads, per-pixel flood fill, texture-width cache or extra idle library is initialized by the health-bar component. Animation option changes no longer request health-art measurement. The former silhouette algorithm exists only in tests/health_width_oracle.gd to check the standard/reserve character bounds.

Regression coverage: fixed/3D graphical health-width checks at 1280x800 and 960x600; default and reserve actors, all facings/idle phases, damage, real settings click, avoidance persistence, movement anchors. Character projection, Oren scale, reserve profiles, original walk directions, compact animation suites, mobile synthetic input, target confirmation and chapter checkpoint tests also run. Android hardware performance is not measured.

## Historical startup measurement of scan removal (base width 24)

Baseline c0feb9c, Godot 4.6.3, Linux llvmpipe, 1280x800. Assets were imported beforehand; disk/shader caches were warm, each first entry used a new process and empty runtime caches. No production instrumentation; the temporary SceneTree driver sends actual New Game mouse events and waits for the map's first drawn frame, then clicks Next Story and asserts progression. Runs were sequential with no concurrent test load.

| Entry | Baseline ms | Fixed width ms |
| --- | ---: | ---: |
| First in new process | 2205.328 | 670.746 |
| Second in same process | 389.148 | 435.920 |
| Third in same process | 422.716 | 389.421 |

First-entry reduction: 1534.582 ms (69.6%). This removes the measured roughly 1.48-second silhouette computation; it does not eliminate every resource/scene/render startup cost. These are bounded samples, not p95 or Android hardware benchmarks. Visual screenshots remain outside Git.

Independent repeat measurements varied: first entry was approximately 6236 ms
versus 4189 ms, and warm entry did not improve. The table above records the
original author's bounded samples, not a universal speedup; no percentage is
promised for Android or other hardware.

Integration onto the mobile-targeting/sequential-event main retains target hover
reset/invalidation, ordered movement and attacks, allied traversal, second-tap
confirmation and the independently fitted battle scene. The old first-launch
test expected one-click movement; its test input now checks the initial preview
and a second click before asserting the authoritative move. Production input
behavior is unchanged by this test correction.

## Base-50 scene-scale candidate

Measured physical widths: 1280x800 fixed and 3D are 50px; 2400x1080
mobile fixed cover is 93.71px, while unzoomed 3D is 67.5px. The latter
difference tracks the camera's scene magnification, not an additional DPI
scale. Height/outline, HP ratios, world anchors, bottom HUD and default-off
avoidance are unchanged. A 1.25x camera zoom produces a 1.25x bar-width
change; no per-actor or texture-derived width cap is applied.

`tests/test_health_scene_scale.gd` covers actual projected backing width,
three aspect ratios, six standard plus two reserve art identities, authored
fixed/3D and custom-map fallback, camera zoom, HP0/partial/full, anchors and
canonical state. Source guards prohibit restoring texture reads, width caches
or idle-library initialization in the component. Existing graphical tests
cover crowded faces and the opt-in avoidance setting. Current startup entry
checks pass; no new device-performance claim or benchmark percentage is made.
