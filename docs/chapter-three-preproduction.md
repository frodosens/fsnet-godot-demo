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

No chapter-three background is admitted by `view/authored_scene.gd`: this
candidate uses the existing generic 3D fallback. No proposed design image is
silently fitted to a different logical grid. New guards have NO final portrait,
map or sideview assets; current generic role fallbacks are diagnostic only.
Do not merge/release as a finished chapter before these gaps are resolved.
Each new identity needs a portrait, four facing map art (canonical FL/BL and
approved mirrored FR/BR), separate idle and walk production, and sideview
idle/attack/hurt with appropriate weapon contact anchors. No source PNG was
added or changed here; no paid generation occurred.

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
a reason to double-apply cover or change authoritative movement speed. No
projection implementation is included until actual production pixels arrive.
