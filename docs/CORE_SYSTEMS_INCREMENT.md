# Core systems increment — 2026-10-26

This is a bounded implementation milestone, not production or release-art certification.

## Implemented

Trusted Lua modules separate grid/sight queries, ability effects, action admission, AI policy, equipment, objectives/story, and snapshots. Only fixed bundled source is assembled; full source and normalized content hashes bind saves/network sessions. Commands accept stable actor/target IDs (legacy indices remain compatible). Rejected commands and caught rule failures discard a candidate state.

Ability definitions: target self/ally/enemy, range bonus, optional integer Bresenham LOS through X obstacles, MP cost, cooldown, battle charges, stationary requirement, physical/magic damage, bounded ordered damage/heal effects. Damage uses flat armor/resist with minimum one; healing caps at max HP. Current content has five combat abilities plus the bandage ability. The existing mobile ember is preserved. Item commands consume the shared bandage count and actor action; directly requesting an unlearned item ability is rejected.

Equipment: nine slots (two rings), item UID/base/quality/generation seed/rolled affixes, derived physical/spell/armor/resist/HP stats, two-piece set, four qualities, bounded victory drop table. Extra movement is capped at +1 action; mobile casting removes only the tagged stationary restriction. First combat command locks gear until terminal outcome. Re-equipping cannot heal or replenish actions. One deterministic victory reward, no reroll on duplicate requests. Inventory cap32; a full bag safely skips reward insertion. This small content set does not claim Diablo-scale balance, crafting or economy.

AI: offensive, defensive anchor/leash, support healing, escort following. Stable actor/target ID ties; commands execute through the same validation/effect functions. AI is part of the one ordered EndTurn command, not independently injected by clients. These heuristics are intentionally limited, not optimal play. Objectives are bounded all/any trees; defeat wins simultaneous satisfaction.

Forms: units/controller/policy, abilities/effects, consumables, bases/affixes/sets/initial gear/drop table, story characters/events, victory/defeat. Scalar fields use native controls, arrays/nested values are editable; larger structural authoring can use the validated JSON view. Save/reload/play tested. No external Lua or original-content overwrite.

## Validation

Linux6.18.55 x86_64, glibc2.41, AMD EPYC9V74 host, process affinity5CPUs; Godot4.6.3 and native Release extension, Lua5.4.7. `tools/test.sh`: bridge111, baseline battle119, modules13, abilities11, equipment23, item/AI10, cut-in/objectives10, vertical19, gear UI5, menu10, editor11 checks (342 total), scene input/camera mapping smoke, plus two three-process fsnet scenarios. Raw output: `validation/core-systems.txt`.

Baseline fight still wins in17steps. Snapshot now v5 and includes inventory/cooldowns/etc, so its hash intentionally differs from the old snapshot layout. Current result `4062ea3ef50bda301d53798c0787f9efbe5f66349438aaa63bf6d8f03027257d`.

Extended real loopback scenario: server + two separate Godot clients; equip movement boots and mobile-cast wand, two moves, AI turn, disconnect, observer uses bandage, driver reconnects then casts focus bolt. Both end step7 with `ecbeb3bb1ba1e98807662ddeb6c54506c162abe3a53ee6504f0fc63ac367c253`. No multi-machine/public-network claim.

## Measured rule budget

A supported-bound fixture (16 AI units,16×16 clear map,movement8) exceeded the original200k-instruction hook: action rejected after2103µs, previous snapshot preserved. Raised the bounded hook to2million, retaining8MiB allocator cap and passing infinite-loop/memory bridge regressions. Final20 repetitions, fresh state each, timing only one Lua EndTurn+Godot adapter refresh: p508710µs,p9510260µs,max11841µs; snapshot1013bytes. This is a local rule/bridge microbenchmark, not network throughput, rendering FPS or worst-case arbitrary-Mod guarantee. Timing varies with shared host scheduling. Content admission now mirrors native depth/key/array/estimated-byte limits, so semantically valid but over-budget data is rejected before VM initialization.

## Remaining gates

Art UI v2 and four-direction sprites need actual asset integration/visual review; existing StyleBox screenshot is functional scaffolding, not approved final art. Environment and all-role animation/effects remain unfinished. No export templates/platform packages, Internet authentication/matchmaking, multihost fault testing or production capacity validation. Data volume and rules are deliberately bounded; more AI strategies/status reactions/complex economies require tests and balance work. Current co-op shares the player-control group, not per-account unit ownership.
