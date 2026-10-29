# Unit definitions and instances: bounded migration

This branch keeps the authoritative Lua rules, numerical snapshot v6, array order,
AI tie ordering, equipment indices, RNG and campaign identity unchanged. It does
not introduce ECS or modify campaign spawns or stats.

Authoring version 2 adds `unit_definitions` and instances with `template_ref`.
Definitions contain baseline stats, abilities and an allowlisted `presentation_ref`.
Instances contain their own unique `id`, position, allegiance, controller/faction,
name and AI policy/anchor/escort. Baseline-stat overrides are rejected. Definitions
are expanded into complete version-1 unit records before validation, hashing,
Runtime construction and saving. Expanded records retain template/profile IDs.
No external template file is consulted when loading a save. Definition edits cannot
change an existing saved session. Both input and expanded content obey the 128 KiB
budget; only 2–16 instances are admitted. Unused definitions are rejected in this
first bounded schema. References never accept paths.

Lua indexes immutable unit configuration by instance ID. State arrays still encode
command order and snapshot rows; they must never be independently sorted or deleted.
HP, equipment, XP, cooldowns, charges and presentation clocks belong to instances.
Presentation profiles select admitted assets and capabilities, not faction or identity.
Legacy version-1 IDs remain a compatibility fallback only; explicit profile references
are authoritative. Unknown profile references fail closed, unknown legacy Mod IDs
retain their existing fallback.

Validation gates: old-source/current-source snapshot and event parity; definitions
expanded identically; edits to source templates cannot alter saved content; duplicate
instance state/equipment/AI isolation; illegal references/overrides/duplicate IDs and
size limits; ID/index command agreement; renamed hero/generic presentation; real
multi-process synchronization and reconnect. Full integration is not ready for main
until these gates and independent review complete.

## Admission and use

An authoring file retains the existing map, abilities, equipment, goals and story.
Set `version` to 2, move a unit's baseline `name`, `role`, `hp`, `mp`,
`movement`, `reach`, `damage`, `armor`, `resist`, `abilities`, and `skill_id`
into `unit_definitions`. Give that record an `id` and an admitted
`presentation_ref`. Replace each spawn with, for example:

```json
{"id":"north_guard_2","template_ref":"watch_guard","x":4,"y":6,"ally":false,"policy":"defensive","leash":3}
```

A second instance can use the same template with a different unique ID, position,
controller, faction and AI policy. `escort` always references an instance ID.
The profile allowlist is `logic/presentation_profiles.gd`; it admits ten existing
hero profiles and the six generic profiles. It contains no external resource paths.
The editor's JSON import expands templates into editable, complete records. This
iteration does not add a graphical template-authoring panel or alter shipped rosters.
Legacy role-based Mod art remains unchanged unless an explicit profile is supplied.
Runtime unit configurations and nested ability arrays are read-only on the adapter
side; Lua only mutates separately allocated instance fields.

## Validation evidence and remaining release gate

`test_unit_legacy_parity.gd` uses checked-in numerical fixtures generated with the
exact frozen release Lua hash across seven released chapter/reference contents:
239 acceptance, snapshot, event and restore assertions. No current template source
is used to interpret old saves. `test_unit_instance_state.gd` covers duplicate
instances, equipment ownership, action/charge isolation, 16/17-unit bounds, invalid
admission retaining the session, saved expansion and mismatched content revisions.
`test_presentation_instances.gd` covers 16 profiles with arbitrary instance IDs,
10-hero cut-ins, canonical map guards and same-state replacement. The old release
and this branch additionally matched 900 cut-in samples (resource path, position,
flip, contact, hit tick and tick duration), generated outside the repository.

Run `tests/run_network.py --unit-fixture` for real transport revision rejection and
three-process reconnect; `tests/run_walk_network.py --unit-fixture` verifies a legal
move while repeated authoritative sync replaces Runtime without replaying its phase.
Neither test mocks transport. Diagnostics/captures remain outside Git.

The broad regression run found a pre-existing fast-shutdown error in
`test_picker_touch_handoff.gd`: all 22 assertions passed, but AudioStreamPlaybackWAV
and `res://assets/audio/magic.wav` survived the immediate engine shutdown. This was
reproduced on a separate imported a6da83a baseline worktree. The test-only teardown
stops presentation, frees its fixture scene/session, and yields process frames for
120 ms of wall time so the audio thread can consume stop/free before deferred quit.
Sound remains enabled and the strict runner is unchanged. Three concurrent reruns,
including verbose fixed-FPS 1000, passed without the resource error. This is a test
shutdown fix, not a claim about an Android device or a production memory fix.

The final candidate preserves main 365db99c's Mara rear-frame/source-facing hotfix
byte-for-byte. All gameplay content and other runtime assets are unchanged relative
to that main. Final independent review is still required before any main merge.
