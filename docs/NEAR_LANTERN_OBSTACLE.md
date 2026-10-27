# Near-bank lantern: bounded content fix

The reference painting puts the near lantern in front of a character standing at
cell `(0,7)`. The old map allowed that cell, while the flat background could not
occlude the actor. Actual Lua commands reproduced this from `(4,7)` via `(1,7)`.
The adjacent `(0,8)` is in front of the lantern and remains usable. Checks at
bridge cells `(4,4)` and `(4,3)` did not establish another occlusion defect.

## Decision

Use the user's fallback: mark only `(0,7)` as `X` and bump the built-in reference
content revision from 1 to 2. All other terrain, spawns, objectives and story are
unchanged. The fixed-background projection contract has the same one-cell edit.
No background/sprite pixels, lighting, character scale, Lua source or native
libraries change. The default reference map still matches the fixed renderer.

A local, uncommitted depth-layer experiment reused the original background
through a measured lantern silhouette. It sorted actors and the transparent
destination ghost at 1280x800, but at 960x600 re-drawing the same source produced
approximately 300 changed lantern pixels even without an overlapping actor.
One bounded attempt to match quad sampling did not remove those differences.
The experiment was not admitted to the game; further sampling/mask work was not
justified for a single optional edge cell. No foreground mask is added.

## Saves and networking

Existing saves embed their complete original content. Loading a revision-1 save
does not rewrite terrain, move a unit or change RNG/state hashes—even if a unit
already occupies `(0,7)`. It retains the old traversable cell and uses the existing
3D compatibility renderer. A visible `旧版地图 · 3D兼容视图` status and tooltip explain
this. Starting a new game uses revision 2 and the approved fixed painting.
Explicit 3D preference is still respected. Arbitrary Mod maps are not forced
into the painting.

The existing content hash changes with the map revision. Old/new peers cannot
silently join with different terrain; the existing handshake rejects them.
All peers should use matching project/content versions. No save format migration
or protocol exception is introduced.

## Validation

- `tests/test_lantern_obstacle.gd`: 104 checks, run headless and graphically at
  1280x800 and 960x600 on Linux Godot 4.6.3, Mesa llvmpipe.
- All remaining walkable cells are connected; all six spawns remain reachable.
- Authoritative rejection of `(0,7)` consumes no action or RNG. `(1,7)` to `(0,8)`
  has a valid two-step detour through `(1,8)`; preview/ghost use that same BFS path.
- Server and two replica VMs agree through accepted/rejected commands; mixed
  old/new content is rejected. Full test runner also exercises real three-process
  network reconnect cases and normal victory/defeat flows.
- New saves round-trip exactly. A genuine revision-1 save with Mara at `(0,7)`
  retains its exact snapshot/hash and can move out normally after loading.
- Optional `AMBER_LANTERN_CAPTURE=/absolute/local/directory` saves actual rendered
  diagnostic frames outside the repository. Review media must not be committed.
- Windows DLL bundle identity/static checks remain valid; Windows graphical
  execution was not performed for this change.

Future fixed-background maps should reserve non-traversable footprints for
painted foreground objects where simple depth handling is insufficient. Confirm
actual overlap first; do not blanket-block neighboring cells or retrofit other
maps without evidence. This fix does not certify occlusion for every background
object or change historical save content.
