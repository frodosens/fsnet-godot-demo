# Battle architecture checkpoint and compatible migration

Status: design/implementation contract, **not a claim that the following systems already exist**. Updated after the user's request to retain all features while correcting extensibility. Keep Lua as shared deterministic rules, GDScript as presentation, and fsnet as transport. No ECS rewrite.

## Original checkpoint facts (before the following incremental implementation)

- `logic/battle.lua:93` is a single reducer with movement, role-based skill branches, enemy scheduling, costs, damage and outcome decisions in one function.
- `battle.lua:96` directly changes enemy positions/HP in end-turn; it does not use the player action validator. Only a nearest-target heuristic exists. No friendly-AI controller system exists.
- The local content increment removes the fixed six-unit/10x8 admission assumptions, but `ally` still mixes faction, controller and UI ownership. A role string still selects heal/area behavior (`battle.lua:127,136`).
- Objectives currently support elimination and limited reach/protect branches (`battle.lua:55`), not composition or explicit simultaneous-result policy.
- `M.events()` exists but has no meaningful attack event stream yet. It is insufficient for a battle cut-in.
- Current snapshots are v2 numeric state plus content hash: RNG, step, unit state, movement-use counters and shared story flags. Ability cooldowns, inventory, equipment and generated item IDs do **not** exist in those snapshots yet.
- `content.gd:86` validates equipment definition tables, but no item generation/equip/affix runtime exists. A registry name in that schema is not an implemented effect.
- UI/story/save vertical slice is implemented locally and tested (19 checks); menu transitions/focus/duplicate input tested (10 checks). Existing bridge battle and three-process fsnet synchronization pass with the content hash. Map/JSON editor files are a draft awaiting testing. Portrait/sprite integration was blocked on Library transfer; an authorized asset branch is now available.

## Six bounded responsibilities

1. **State, phase, snapshots**: actor IDs, factions, controllers, position/HP/resources, movement/action budgets, charges/cooldowns/status, RNG, story flags, inventory/item UID counter, equipment, outcome. Canonical versioned encode/decode; no scene objects or wall clock.
2. **Actions, targeting, effects and abilities**: one validator/executor for player, friendly AI and enemy AI. Ability definitions hold target rules, costs, cooldown/charges and ordered effects. Ordinary attack is an ability. Effect operations are a small trusted registry, not user-supplied Lua.
3. **Items and equipment**: deterministic generation, inventory and slot ownership; consumables use the same ability/effect pipeline. Derived stats and capability modifiers are computed centrally. Equipment definitions never inject code.
4. **AI**: pure, bounded policy selection using the same legal-action query. Offensive, defensive, support and escort policies produce normal actions; stable tie order by actor ID/cell. No separate direct HP/position writes.
5. **Objectives and story triggers**: bounded `all`/`any` objective trees with eliminate, protect, reach and survive leaves. Evaluate after a complete action's effect batch; defeat wins simultaneous terminal conditions unless content explicitly selects another supported tie policy. Terminal outcome latches once and stops subsequent actions. Story triggers are shared flags; reading cursors stay local.
6. **Content**: one versioned definition registry for units/controllers, abilities, items/affixes/sets, objectives and story. IO/path/size admission stays at the host; shared rules own semantic references and legal gameplay constraints. Immutable definitions are separate from mutable state.

## Public rule interface

```text
initialize(content, seed) -> state summary / diagnostics
legal_actions(state, actor_id) -> bounded action descriptions
validate(state, command, caller_context) -> typed rejection or cost/target plan
apply(state, command, caller_context) -> accepted state + ordered events + hash
snapshot(state) / restore(snapshot, expected_rules_hash, expected_content_hash)
```

The accepted action pipeline is:
`identity/controller + phase -> target/range/path checks -> resource/cooldown checks -> candidate-state costs -> bounded effects -> objectives/story -> commit candidate + events`.
A rejected or budget-failed action must leave state, RNG, charges and inventory unchanged. Replay uses the exact same path and never duplicates presentation side effects.

Use stable `actor_id` and target IDs in canonical commands. Existing unit-index commands may be translated only at the compatibility boundary while migrating UI/tests. Roles describe visuals/default content; they do not select engine behavior.

Separate `faction_id` (relations) from `controller={kind:player|ai, policy, group}`. First chapter remains three player-controlled mercenaries against three enemy controllers; friendly AI is exercised in a small content fixture without inventing extra plot characters. Local co-op initially shares the party control group; it is not an account/ownership service.

## Authority and AI scheduling decision

Choose **deterministic AI expansion inside the accepted EndTurn action** for this small turn-based demo. Every VM executes the same ordered AI phase, but only as part of that authoritative command. AI calls the same action pipeline using an internal system capability that cannot be supplied by a network payload. Clients never freely submit system/AI actions. This retains the existing command/round model and avoids a new asynchronous scheduler.

AI evaluates only bounded candidates, stable ties and no ambient randomness. Offensive closes/attacks; defensive protects an anchor/leash; support heals/buffs legal friendly targets before attacking; escort follows a referenced unit/zone while responding to nearby threats. These are limited policies, not an optimal tactics claim. All policies must pass the common legality tests.

## Abilities, consumables and special equipment

First content set: normal melee/ranged/magic attack, existing self-heal/strong shot/ember abilities, one genuinely stationary `focus_bolt`, and one healing consumable. Costs, target relations, MP, cooldown/charges and area effects are definitions. Current mobile ember must not be silently nerfed to make an equipment effect look useful.

Nine slots: main hand, off hand, head, body, hands, feet, neck, two rings. Small first base/affix/drop tables; normal/magic/rare/one unique example and one two-piece set demonstrate extension points, not Diablo content volume. Item UID, generation seed and rolled results enter state/snapshot/replay. Both ends consume the same RNG sequence; clients never roll independently.

First two actual capability modifiers:
- `move_action_plus1`: movement **actions**, not distance; additive with a first-version cap of +1, budget granted once at turn start.
- `mobile_cast`: removes the stationary constraint only from abilities carrying the corresponding constraint tag; does not grant an action or refund MP.

First equip policy: preparation/post-battle only; the first combat action locks battle equipment. Unequip/re-equip never refunds resources, actions or movement. More permissive mid-battle gear rules need a separate explicit design. Stat ranges, stacking, phase hooks and effect-operation budgets are bounded. Attack-then-move, adjacency guard and burning-ground reactions remain candidates, not implemented claims.

## Mod, save and protocol contract

Mods are validated data-only JSON. No external Lua, executable resource path or arbitrary file reference. Preserve built-in content; user modifications live under `user://mods`. Enforce size, depth, map bounds, nonoverlapping spawns, ID uniqueness, references, permitted effect operations and objective-tree bounds. The editor must actually save, reload and launch its validated content.

Rules hash must cover the full fixed module list, not just the entry file. Content hash covers canonical normalized definitions including story and equipment. Multiplayer start/sync and saves bind both. Schema changes produce explicit incompatible-version feedback; never silently interpret old snapshots with a new layout. Local story cursor/seen presentation state and combat animations are excluded from the shared hash, but saved alongside the deterministic snapshot.

## Incremental migration and first-chapter acceptance

1. Preserve the tested UI/story/save checkpoint and original bridge battle. Introduce the six responsibilities with behavior-preserving replay tests; no new gameplay balance at this extraction step.
2. Route enemy and friendly AI through shared validation; move the current abilities into definitions. Test friendly targets, insufficient cost, range/LOS, cooldown/charges and action budgets.
3. Replace outcome branches with bounded objective evaluation. Bridge chapter keeps nonlethal elimination/party-defeat semantics; protect/reach/survive use separate tiny fixtures.
4. Add deterministic inventory/equipment and the two capability modifiers with UID/seed snapshot roundtrips, duplicate-command, invalid-command and gear-budget exploit tests.
5. Connect the editor to these schemas and the UI to legal action descriptions; integrate the approved art via its stable IDs. Add cut-in events after logic resolves, with speed/skip controls and no rule dependency on animation completion.
6. Final playable flow: new game -> opening dialogue -> movement/ability/item -> AI phase -> shared round story -> save/load exact RNG/step/cursor -> win/lose ending -> return. Repeat online with two client VMs, reconnect/replay and mismatched-content rejection. Capture only real completed scenes with the exact source commit recorded.

Existing bridge budgets (8 MiB VM, instruction hook, bounded native values) are constraints to measure, not a promise of arbitrary mod scale. If the planned maximum content exceeds a measured budget, reduce supported bounds or change an explicitly documented limit; do not ignore budget failures.

## Implemented increment

The UI/editor/art checkpoint is now exercised. Rules are assembled from a fixed lexical module list (`board`, `objectives`, `actions`, `ai`, `snapshot`) into one sandboxed chunk; no external loader or Mod code execution exists. Both saves and peers hash the complete assembled source. AI invokes the common action executor; optional faction/controller fields and stable actor IDs are supported. Rejected actions execute on a candidate state and do not commit. Composite objectives and settled attack events are implemented. Original bridge replay still ends at step 17 with the same state hash.

This is the first compatible extraction, not the complete six-responsibility destination: role-based skill selection, inventory/equipment runtime, reusable ability cost/cooldown definitions, advanced AI policies and richer editor forms remain pending. The screenshot cut-in is only the Mara/Oren sword slice.

## Core systems increment

Data-defined ability target/cost/cooldown/charges and bounded damage/heal registry now replace role branches. Gear, deterministic drop generation, nine slots, set bonuses, extra movement and mobile casting are implemented. Shared consumable supplies invoke the same ability executor through an internal capability. Snapshot v5 covers all of these values. AI policies now include offensive, defensive, support and escort; stable actor ordering and common action validation remain mandatory. Editor forms edit these definition tables and launch validated content. Remaining boundaries are content/balance scale, advanced reactions and animation coverage, not missing first-version inventory or AI pipelines. See CORE_SYSTEMS_INCREMENT.md for concrete tests and limitations.
