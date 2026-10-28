# Chapter three content candidate — art not approved for runtime

Base: main 156344d. This isolated candidate implements the approved 10x9 topology,
three returning allies and TWO new guard identities: `rodd` (knight) and
`vera` (archer). These are existing rule professions, not new classes.
The signed-receipt inquiry follows chapter two's unresolved reconciliation;
medicine has already been delivered. Knocked-out guards are not killed.

The map has 62 walkable cells, goal (8,1), Mara/Finn/Neri at (3,7)/(2,7)/(4,7),
and guards at (3,3)/(6,2). Two routes remain with enemy spawn cells blocked:
west 13 edges, east 11. Real shared-Lua commands complete the east route in four
player turns with Mara at 12 HP and both guards alive. This is introductory
balance, not exhaustive strategy validation; the archer's initial position
allows that route to avoid damage. Existing AI, allied traversal and occupied
endpoint rules are unchanged. Natural protected-Mara defeat also tested.

## Missing art / release gate

The initial content-only stage used generic 3D; the background integration
status is recorded below. No proposed design image is
silently fitted to a different logical grid. New guards have NO final portrait,
map or sideview assets; current generic role fallbacks are diagnostic only.
Do not merge/release as a finished chapter before these gaps are resolved.
Each new identity needs a portrait, four facing map art (canonical FL/BL and
approved mirrored FR/BR), separate idle and walk production, and sideview
idle/attack/hurt with appropriate weapon contact anchors. Background PNGs were subsequently admitted unchanged; no guard PNGs or paid
generation were produced by this implementation task.

## Chapter persistence / multiplayer

`App` now selects a successor for the two known chapter IDs. Chapter one keeps
its exact `chapter1_end_` identity computation; chapter two uses independent
`chapter2_end_` content-addressed immutable saves. Validation binds the prefix
to the EMBEDDED saved content, not the currently open chapter. Both namespaces
appear in the load menu. Failure to persist or validate the checkpoint blocks
entry; autosave and manual slots cannot overwrite it. Old saves retain their
embedded content and inventory. Chapter three intentionally starts its own
configured party, inventory, HP/MP and actions; confirmation says so. There is
no new carryover schema or automatic transfer of loot.

Online rooms retain immutable content: transition is refused while online;
both users must choose chapter three in the network menu and enter a new room.
Existing content hashes, reconnect/replay and rules versions remain unchanged.

## Reproduction

- `tests/test_chapter_three_layout.py`: exact terrain, routes and blocked water.
- `tests/test_chapter_three.gd`: actual Lua victory/defeat, allied pass-through,
  destination occupancy, replay, chapter-two ending gate, checkpoint failure,
  immutable state/inventory restore, chapter-three autosave and reload.
- `tests/test_chapter_three_scene.gd`: real mouse chapter-two ending → cancel/
  confirm chapter-three entry, intro/pause/resume, legal preview/cancel at
  1280x800 and 960x600. Generic diagnostic art is not visual acceptance.
- `AMBER_MOD=$PWD/content/mill_receipts.json AMBER_TEST_WAIT=1 python3 tests/run_network.py`:
  authority and two separate clients, same state after reconnect.
- Existing chapter-one checkpoint and chapter-two tests remain unchanged.

Linux Godot 4.6.3 Compatibility/llvmpipe only. No Windows or Android device test,
no new APK, no main merge, no review images/video in Git.

## Pending authored-scene projection contract

Producer design coordinates at 1280x800: origin (618.8,120.34128),
basis X=(42.4,29.98104), basis Y=(-42.4,29.98104). The 0.7071 vertical
ratio is unchanged, but cell size differs from chapter two; this cannot be
implemented as an origin-only shift. Chapter-specific camera size/admission
and a single cover transform must be calibrated against the delivered clean
map. Actor apparent height (~90 pixels) is a separate validation target, not
a reason to double-apply cover or change authoritative movement speed. The production pixels have now arrived; the calibrated implementation and
validation are recorded below.

## Background integration candidate (not final guard-art acceptance)

The four-file production background package is now present. Source SHA256s
match both contracts. `authored_scene.gd` admits only the unchanged chapter-three
terrain and validates the bundled projection contract; modified maps still use
3D. Authored camera height is 13.3416386 world units. Base projected cell basis
is (42.4,29.98104)/(-42.4,29.98104); maximum tested grid-center error is below
0.4 logical pixels including wide-phone cover rounding. A render-only scale
factor compensates the larger orthographic size, retaining Mara's ~90px body;
`character_scale` stays 1.25 and movement velocity/cadence are unchanged.

Ground marks outline playable-to-X/off-map interfaces (not invented walls),
and the existing gold cell texture marks the office forecourt at (8,1). Four
measured painted-lamp anchors illuminate actors only. The map image remains
unchanged, with no new foreground masks or passage changes. Both new guards now use their own portrait, four canonical map facings and battle poses. Missing or invalid contracts retain a diagnostic fallback with a warning; this is not the accepted shipped identity.
The battle background shares the existing 642px floor anchors. Known-character and new-guard cut-in fixtures cover composition, own-side-left layout, melee contact and arrow impact.

`test_chapter_three_art.gd` covers 1280x800, 1024x768 and 2400x1080, all 62
projected/picked cell centers and 96 topological adjacencies, view switching,
scale, boundary/goal marks, actor lights, and cut-in composition. Actual Lua
adjacency probes cover 95 legal single-step edges plus the one edge whose start
is already the victory goal (correctly terminal). `capture_chapter_three_clearance.gd`
uses explicitly labeled display-only Mara placements at all 62 cells with an
unchanged snapshot; it is not a record of legal commands or full gameplay.
The inspected contact sheet showed no conspicuous Mara foot clipping, but does
not certify all future guard silhouettes or animated transition sweeps.

## Guard integration candidate

Rodd and Vera retain knight/archer rules, not new professions. Their 128x128
map canvases use root (64,120), without cropping weapons or changing body scale.
Both map idles and both battle idles are static. Rodd also moves statically.
Vera alone uses eight weighted frames per canonical left-facing direction;
right-facing motion mirrors these around root x64. Each complete grid interval
is one cycle; stopping restores the distinct unmirrored canonical idle.
`vera_motion_enabled` is a presentation-only fallback switch, not a saved rule.
The motion remains provisional: torso yaw, bow flex and leg crossing remain.

Battle timing is unchanged: 24 ticks at 60ms; Rodd contact tick9, Vera arrow
release12 and impact16. Supplied hurt coordinates are already defender-left;
they are not mirrored a second time. All original actors keep their bindings.

The new guard and background JSON contracts are explicitly included by the
Android export preset; an editor import alone would not guarantee packaging.
No Android device or Windows runtime acceptance is claimed by Linux tests.

Guard acceptance evidence (Linux Godot 4.6.3 / llvmpipe): 4,840 graphical
checks across fixed-background 1280x800/2400x1080 and 3D 1280x800/960x600;
38 neutral-canvas checks; 99 asset/export-admission checks. Real Vera movement
observed 31 Runtime replacements in each of four directions without phase
restart, then static idle/flip reset. Chapter-three server/two-client reconnect
produced identical state hashes. Two 62-cell display-only contact sheets showed
no conspicuous canonical-foot clipping on bridges or the forecourt; this is
not a claim of pixel-perfect occlusion for every animated silhouette. Actual
command-driven footage includes all four Vera facings, Rodd melee and Vera
arrow attack from the enemy side. Fixed-frame movie capture preserves normal
simulation timing; the onscreen throughput counter is not device performance.

The full regression's 98 reported check groups passed before its shell reader
was interrupted by editing the test list while it was running. The remaining
migration/Adela/Vera/chapter-network section was restarted from its first
unexecuted section; no gameplay test failure was suppressed. A final clean
checkout separately imports and loads the new profiles and export contracts.
