# Chapter two: the old watchhouse letter

Candidate following chapter-one victory. Medicine has already reached White Elm's pharmacy; the sealed watchhouse letter and unresolved accounts lead to the next morning's visit. Adela and Elsbet are newly proposed watchkeepers using existing art IDs and legal knight/mage rules, not new classes. The encounter ends when Mara delivers the sealed letter; knocked-out units are not narrated as killed. No stolen ledger, recruitment, or world-crisis plot is introduced.

## Content and geometry

`content/white_elm_watchhouse.json`, schema 1/revision 1, is a separate 10x8 map. Compared with the original planning draft, only (7,1), (8,1), and (8,2) become road. Mara's reach objective moves from (7,2) to (8,1). All initial spawns remain unchanged. Protect-Mara is the defeat condition. The 59 walkable cells retain both routes around the central four blocked cargo cells. With initial occupancy, both route lengths are 11, not the draft's nine. Moving guards can change reachable routes.

At 1280x800, grid origin is approximately (592.060,83.900), basis (+47.9395,+33.8983)/(-47.9395,+33.8983), goal (927.636,388.985). The camera keeps orthographic size 11.8; only this scene uses camera-right +1 and camera-up +0.0375233 world offset. Switching to 3D restores the original camera. Existing actor scale 1.25, per-actor Oren factor, foot anchors, HP, range and route rendering remain intact. Both supplied backgrounds are original 1586x992 files, never rewritten; the map plane preserves their aspect ratio. Screen coordinates are logical canvas coordinates under Godot canvas scaling.

The wall and door remain behind characters at the inspected door/approach placements. Cargo stays inside the four-cell blocked footprint. No foreground mask or dynamic occluder was added. The small watchhouse looks compact relative to ~90px people, particularly when crowded; this aesthetic limitation is retained rather than shrinking actors. Geometry captures use explicit legal test placements, not a claim of full gameplay.

## Chapter entry and compatibility

After the first chapter's victory dialogue, an explicit button opens confirmation. The previous chapter is saved to a separate content-addressed chapter checkpoint before transitioning; failure to save stops transition. It is listed in the load UI. Chapter-two autosaves and normal save-slot calls cannot overwrite it; manual saves remain untouched. Repeating an identical transition reuses a verified checkpoint; a different state creates another checkpoint rather than replacing an earlier recovery point. The confirmation explicitly says chapter two starts a fresh configured party with restored HP/MP/actions and predefined equipment; it does not carry the previous battle inventory. There is no broader campaign progression schema in this candidate.

Existing format-2 saves continue loading their embedded content and exact snapshot, including previous chapter-one revisions. Lua/native sources and rule hashes are unchanged. First-chapter content and runtime assets are unchanged.

An online room has immutable content. A client cannot invoke local-only chapter advancement. The UI explains that both players must leave and select chapter two in the existing network menu to create/join a new room; content hash mismatch remains rejected. This is explicit room restart, not a seamless network campaign transition. Existing local-loopback-only networking restrictions remain.

`view/authored_scene.gd` admits only built-in IDs with matching dimensions and terrain, selecting each map and combat background. Modified/custom layouts retain the 3D/generic combat fallback. It does not trust arbitrary resource paths from mods.

## Reproduction and limits

- `tests/test_chapter_checkpoint.gd`: failed checkpoint write blocks transition; checkpoint bytes are immutable across autosaves, repeated entry and different ending histories; manual saves survive, corrupt checkpoints fail closed, and invalid slot names are rejected.
- `tests/test_chapter_two.gd`: validated content, actual shared-Lua four-turn reach victory with both guards alive (Mara 7 HP, step 7), natural protect-Mara defeat, replay, save/load, ending gate, online transition refusal and fallback admission.
- `tests/test_chapter_two_scene.gd`: real GUI clicks from a labeled chapter-one terminal fixture, chapter entry/dialogue/pause, 1280x800 and 960x600, projection/picking, reversible 3D/fixed camera, route preview/cancel and chapter-specific combat background/right mirrored portrait.
- `tests/test_chapter_two_playthrough.gd`: GUI old-save loading, chapter entry, actual chapter-two Save and Leave, load-menu recovery of the exact chapter-one snapshot/inventory/reading state, repeated entry, four confirmed moves, AI turns/cut-ins, reach victory, save, menu return and exact reload. The default test skips presentation waits; `AMBER_CH2_MOVIE=1` waits at normal simulation speed for actual motion/cut-ins and dialogue. Movie Maker `--fixed-fps 60 --write-movie /local/output.avi` is offline recording, not a performance measurement.
- `AMBER_MOD=.../content/white_elm_watchhouse.json AMBER_TEST_WAIT=1 python3 tests/run_network.py`: real authority plus two separate clients, reconnect and same state.

Balance is introductory: a west-side route succeeds without attacking. This is not exhaustive strategy/balance testing. Linux Godot 4.6.3 Compatibility/llvmpipe tested; Windows visual execution is not claimed. Review images/video remain outside Git.
