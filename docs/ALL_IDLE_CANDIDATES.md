# Six map idle candidates and two battle neutral clips

Work branch only. Main merge requires separate review. No shared Lua, native
code, Windows DLL, movement speed, combat timing or old source images change.

## Enabled states

- Map: Mara, Finn, Oren, Tessa and Bram have four diagonal directions, three unique
  poses each, sequence0/1/2/1 at400ms (1600ms). Neri has two unique poses,0/1/0
  at400ms (1200ms); neutral spans800ms across the wrap.
- Movement is still a static directional slide, **not a walk animation**. The
  first frame of the configured unit/direction is used at movement consumption,
  each segment, turn and settlement. Idle resumes from that same frame. This
  avoids swapping between old and new silhouettes when motion starts/stops.
- Bindings are restricted to the six stable unit IDs. Other Mod units sharing a
  role retain their prior directional art. Original source textures are retained.
- Battle: Mara uses `mara:right`; Oren uses `oren:left` **only when defending**.
  The right-facing Oren enemy attack group is distinct and remains single-frame.
  Finn/Neri/Tessa/Bram battle idle still falls back to original neutral frames.
- Attack, brace, hit, recovery, death and final settle poses keep precedence. No
  new battle idle scene or delay is added. See MARA_BATTLE_IDLE_CANDIDATE.md for
  the limited100ms visible Mara defender inhale window. Oren defending against
  Mara can show inhale320–640ms before brace at~667ms.

## Asset sources and known limits

Map source branch tip8344783adc8a7f965f94e71ae578fed9dd740bc0 contains corrected
alpha>=128 half-open bounds, including the five character metadata files. It
includes7d21e6681675f5b243250d70a113bfe928a1dac8 and its earlier asset commits.
Oren battle source1af9ea624d7a3591cda20a1bc39eea5105646298 includes left-facing
neutral source provenance and explicit low-alpha residue. Mara source and alpha
correction are recorded in the separate battle document.

Actual source pixels and both rendering modes were inspected. Bram is6–7source
pixels wider than the old silhouette; his back-left/back-right bottom/width vary
about1pixel across poses. Mara and Oren retain slight boot/outline movement. Neri's
robe expands up to2pixels in one view and her two-pose rhythm is less varied.
These are art limitations, not corrected by bobbing, stretching or changing feet
world positions. Battle inhale images retain faint alpha residues; the originals
were not thresholded or cropped. No claim of final art acceptance or zero drift.

## Validation

`tools/test.sh` includes `test_all_idle_candidates.gd` (434 checks): all6×4
bindings, phase order, fixed world position, pause/reduced motion, unit-scope Mod
fallback, immediate static neutral when movement begins, every direction's
slide/settle, unchanged snapshots, and Oren's separate left defence/right attack
contract. Existing movement, idle boundary, map projection, combat and network
regression suites remain enabled. The complete candidate run passed5033 checks
and5 server/two-client network cases, with no script errors.

Actual captures use Linux Godot4.6.3 Compatibility/llvmpipe,1280×800 and960×600.
The map clip starts through New Game, then uses a labelled presentation-only
four-direction fixture, followed by a real Lua move, pause/resume and original3D
renderer switch. Direction fixtures do not issue gameplay commands. Camera-facing
sprite projection, light response, ground shadows and overlay depth are retained.
Images/video are review deliverables outside Git, not runtime assets or performance
benchmarks. Windows runtime and other devices were not tested here.

Same-frame move consumption followed immediately by skip also resets the idle
clock explicitly; it does not depend on MapIdle processing an intermediate frame.
The final regression includes this boundary.
