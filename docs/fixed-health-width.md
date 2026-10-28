# Fixed map health-bar width

Map health bars use one 24-logical-pixel width, scaled only by the viewport pixel ratio. Actor scale, facing, animation, experimental options, and role do not change that width. The existing thin frame, HP fill, damage/selection feedback, world anchor and opt-in face avoidance remain intact. Extremely narrow custom Mod art is not measured automatically.

This replaces runtime per-texture silhouette measurement. No image reads, per-pixel flood fill, texture-width cache or extra idle library is initialized by the health-bar component. Animation option changes no longer request health-art measurement. The former silhouette algorithm exists only in tests/health_width_oracle.gd to check the standard/reserve character bounds.

Regression coverage: fixed/3D graphical health-width checks at 1280x800 and 960x600; default and reserve actors, all facings/idle phases, damage, real settings click, avoidance persistence, movement anchors. Character projection, Oren scale, reserve profiles, original walk directions, compact animation suites, mobile synthetic input, target confirmation and chapter checkpoint tests also run. Android hardware performance is not measured.

## Comparable startup measurement

Baseline c0feb9c, Godot 4.6.3, Linux llvmpipe, 1280x800. Assets were imported beforehand; disk/shader caches were warm, each first entry used a new process and empty runtime caches. No production instrumentation; the temporary SceneTree driver sends actual New Game mouse events and waits for the map's first drawn frame, then clicks Next Story and asserts progression. Runs were sequential with no concurrent test load.

| Entry | Baseline ms | Fixed width ms |
| --- | ---: | ---: |
| First in new process | 2205.328 | 670.746 |
| Second in same process | 389.148 | 435.920 |
| Third in same process | 422.716 | 389.421 |

First-entry reduction: 1534.582 ms (69.6%). This removes the measured roughly 1.48-second silhouette computation; it does not eliminate every resource/scene/render startup cost. These are bounded samples, not p95 or Android hardware benchmarks. Visual screenshots remain outside Git.
