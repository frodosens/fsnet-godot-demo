# Deterministic progression v1 — review candidate

Baseline: `1ad8e604c66c1befdb7f79fe630e1ba1735212b6`. No chapter 4–8 work,
art/default animation changes, new abilities, or inventory inheritance.

## Rules and balance (central trusted Lua configuration)

`logic/rules/progression.lua`: cumulative thresholds 0,60,150,270,420,600,810,
1050,1320,1620 (levels 1–10). Each level adds 1 base HP; adds 1 maximum MP only
if this chapter's base MP is positive. Every two gained levels adds 1 base attack.
Physical and magical damage, including read-only preview, use the grown base.
Healing amounts, armor, resistance, movement, range, action limits and abilities
are unchanged. These are conservative initial numbers, not a balanced campaign claim.

Only victory settles XP: 90 victory XP plus 30 for each defeated opposing unit.
All deployed `controller=player` units share it, including knocked-out participants.
Integer remainder goes in ascending stable unit-ID order. Failed battles award zero.
No per-hit/healing XP and no reward for explicitly replaying a completed chapter
within the carried campaign ledger. Rewinding an entire older save remains a save
branch, not an account-wide anti-cheat ledger. Completion is keyed by content ID.
Capped units do not redistribute their excess share. Leveling never heals, restores
MP, resurrects, resets actions/charges/cooldowns, or draws extra RNG.

Equipment continues deriving on top of grown base stats. Unequip clamps HP to the
new maximum; re-equip never restores HP. Equipment remains preparation/terminal
only and team-shared, as do consumables. New chapter inventory/equipment/supplies
still reset to that chapter's preset. New chapter HP/MP initialize full normally.

## Stable UI contract

Read `Runtime.units[i]`: `level`, cumulative `xp`, `xp_floor`, `xp_next`,
`base_hp`, `base_damage`. Progress numerator = xp-xp_floor; denominator =
xp_next-xp_floor. At cap the denominator is zero: show max level, don't divide.
Read existing `hp/max_hp/mp/max_mp/damage/spell_bonus/armor/resist/movement/reach/
move_actions` for actual final battle values. Clone the current snapshot for gear
preview; do not initialize a level-one replacement to estimate equipment changes.

`Runtime.progression` contains `{campaign, config, settled}`. Campaign is
`{roster:[{id,xp}], completed:[chapter_id]}`, canonical sorted order; config contains
`thresholds/kill_xp/victory_xp/hp_per_level/mp_per_level/attack_every_levels`.
`Runtime.campaign_state()` returns a detached copy. Events appended at terminal:
`{kind:"experience", actor:stable_unit_id, amount:actual_increase, xp:new_total}`.
No grant-XP command exists. UI fields are derived views, never authority writes.

## Persistence and networking

Snapshot v6 stores bounded integer campaign data and settlement flag in the
canonical state. Limits: 32 roster records, 32 completed chapter IDs, ID length40,
XP<=1620. Normal network restore rejects v5; rules/content handshake remains strict.
Host authority determines the initial campaign and all settlement. Fresh clients
receive its complete snapshot; reconnect/tail replay cannot grant rewards twice.
`Runtime/Authority.new(data,campaign)`, `Session.offline(data,campaign)` and
`App.new_game/start_room(...,campaign)` accept validated host-side initial state.
No client command can inject campaign values. Online chapter hot-swap remains
unsupported. This exposes new-room host seeding; no new online campaign selection
UI or internet hosting is claimed.

Offline `App.enter_next_chapter` writes the immutable ending checkpoint first,
then passes the campaign to the next chapter. Failed writes preserve current game.
Roster records are keyed by stable identity, independent of per-map array order;
absent identities retain XP, AI-controlled incarnations do not receive player growth.

Save envelope format3 wraps v6. Trusted old format2/v5 saves are validated in the
frozen baseline rule VM (`logic/legacy_v5_rules.lua`, pinned SHA256 in Runtime).
Original content/hash/state and old checkpoint ID are checked before migration.
Migration uses XP0/level1, preserving old HP/MP/inventory/actions/etc.; old terminal
victories are marked completed with no retroactive reward. The in-memory snapshot
and hash become v6; original files and content-addressed checkpoints are not rewritten.
Saving to another ordinary slot produces format3. The previously supported v5
snapshot-only predecessor remains accepted, but its command/network hash does not.

## Validation and known baseline test failures

Dedicated commands:

```
godot --headless --path . --script tests/test_progression.gd
godot --headless --path . --script tests/test_progression_save.gd
godot --headless --path . --script tests/test_progression_limits.gd
python3 tests/run_progression_network.py
godot --path . --script tests/test_progression_scene.gd
```

Real three-process authority/two-client test seeds host XP59, settles XP89, passes
16-command checkpoint compaction and both clients reconnecting; exact offline
snapshot comparison. Existing standard, extended gear/item and Mod network tests
also pass. Max legitimate fixture snapshot12831 bytes/reply13135 bytes fits native
limits without native changes. Actual viewport touch attacks through victory at
1280x800 and2400x1080 drain XP events and leave chapter-entry story usable.
Linux Godot4.6.3/llvmpipe; no Android/Windows device result claimed.

The full runner does NOT currently pass on unmodified baseline either. It stops at
`test_neri_mirror_edges`: legacy mirrored animation expectations conflict with the
new default hero refresh. Continued candidate groups expose 14 additional failing
legacy visual tests, each independently rerun on pristine `1ad8e604` with identical
failure labels: all_idle_candidates, character_projection, finn_sequence_scene,
fixed_background, idle_only, idle_only_scene, idle_slide, map_sequence_scene,
mara_idle_candidate, neri_mirror, oren_map_scale, reserve_art, walk_cycles,
walk_direction_batch (all with test_ prefix). No animation fix or fixture rewrite
is hidden in progression. Local comparison logs are /tmp/progression-base-* and
/tmp/progression-rem-*. The remaining suites were run independently rather than
claiming the failed monolithic runner completed successfully.
