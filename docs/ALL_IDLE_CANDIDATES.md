# Six map idle candidates and received battle neutral clips

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
  The right-facing Oren enemy attack group is distinct and retains its authored
  action timeline.
  Finn, Neri, Tessa and Bram also use unit-scoped right-source clips (mirrored
  when defending). Oren-right is a seventh separate source binding; its short
  attacker opening does not reach the inhale frame. See the final integration
  section below.
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
regression suites remain enabled. The previous map/two-battle candidate run passed5033 checks
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


## Finn/Neri follow-up

Received Git source `f7b28c4b77a8a37ae2fc3c06817d58c59674092f` supplies the
right-facing original neutral + inhale + neutral at320ms for both. Each binds
only its own stable unit ID. Real AI attacks against Finn and Neri were used to
verify mirrored passive inhale320–420ms, unchanged brace/hit/recover,1×/2×/4×
playback and original own bow/cast animation frames. These are not full visible
breathing cycles during the short active attack opening.

Earlier Tessa/Bram asset transfer attempt: Library
`libfile_16ed3b1dca8481918eb4e826299023d4` preparation succeeded, but the standard
materialization helper returned `library file transfer failed: download failed`
(exit1), before a local ZIP was installed. No bytes, ZIP hash, PNG or manifests
were verified here. The helper supplied no HTTP status or underlying cause;
this is an unresolved transfer failure, not a confirmed permissions denial.
No raw download URL, alternative file host or unverified replacement was used.
The prior candidate and tests remain usable without these optional clips.

Finn/Neri follow-up full regression:5111 checks and5 real multi-process network
cases passed. Actual1280×800 and960×600 captures cover both new defenders.


## Final received battle assets and exact visibility limits

Git source `781f0ba5325e8ad894adf298b54822beaf3f14db` subsequently supplied the
three previously unavailable PNGs and their provenance. The failed Library ZIPs
were not used or retried. Original source hashes/metadata are retained; no alpha
cleanup or whole-pose redraw was performed. All seven192×160 clip bindings load:
Mara-right, Finn-right, Neri-right, Oren-left, Oren-right, Tessa-right, Bram-right.

Actual gameplay timing remains24ticks. Each clip has neutral/inhalation/neutral,
320ms per slot, but authored combat states gate when it can be sampled:

| Runtime state | Visible inhalation at1× in tested fixture |
| --- | --- |
| Mara/Finn/Neri defending against Oren | 320–420ms,100ms |
| Oren-left/Tessa/Bram defending against Mara | 320–640ms,320ms |
| Mara attacking | none: first neutral window~167ms |
| Finn/Neri/Tessa/Bram/Oren-right attacking | none: neutral sampling window120ms |

Thus all six **defenders** show a new pose without changing combat pacing;
Oren-right has a valid separately sourced clip but its new inhale is not visible
in the present attack opening. This is not seven fully visible breathing loops.
Making the active actor breathe through a whole cycle would need a separate
idle staging window or a considered phase/timing design. No hidden delay, new
counterattack, idle-over-recovery replacement or faster artificial cycle was added.

`test_all_battle_idles.gd` checks all7 clip clocks, identity restrictions, left/right
source separation, Tessa/Bram real Lua attacks, all key state priorities, paused
tree,1×/2×/4× processing, duplicate/queued events, skip, death and the explicit
Oren-right short-window limitation. Previous tests cover the other four defenders.
The actual capture uses six independently initialized adjacency fixtures and real
Lua attacks/AI turns; captions identify fixture status, normal playback is not
slowed to manufacture breathing visibility.1280×800 and960×600 are captured as
actual viewports, not resized screenshots. Windows execution is still untested.

Final seven-source candidate regression:5234 checks plus5 real server/two-client
network scenarios passed. Six real defender-event captures passed in actual1280×800
and960×600 viewports. Sparse low-alpha source residues remain disclosed; no obvious
grounding defect from the isolated faint pixels was visible in these backgrounds.
This is bounded visual inspection, not clean-alpha certification on all backgrounds.
