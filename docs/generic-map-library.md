# Controlled generic runtime catalog

Six verified map packages are admitted by exact IDs. This candidate adds no campaign spawns, chapter text, balance values, portraits or authored battle sprites. It builds on main `7b50a0b99a1186757672bdb50fbf4a5797c53f83`, retaining the reviewed Neri standing-idle correction and character-details/XP/latest-map release; no broad unit abstraction refactor is included.

## Chapter/editor contract

`view/generic_map_art.gd` exposes:
- `templates()` returns detached metadata entries `{id,name,profile_id,portrait_available:false,authored_battle_available:false}`.
- `canonical_id(unit_id)` resolves the exact allowlist below, or returns an empty string.
- `declared(unit_id)` tests admission; `profile(unit_id)` returns `{map,library,static_fallback}` or an empty dictionary.

Use an ID below in the existing content `units[].id` / editor's **稳定 ID** field. Keep authored `role`, HP, damage, abilities, faction, controller and other ordinary fields; art admission supplies none of those. Existing JSON validation still checks unique IDs, references, legal positions and fields. Do not add arbitrary texture paths or a new unrecognized `profile` property to chapter JSON. When changing an existing ID in the editor, update story/goal/escort references before applying, as with any ID edit.

| Canonical template ID | Own map art | Known limits |
|---|---|---|
| generic_soldier_01 | Existing Mini soldier | Helmet/shield/sword intact; sole pixels can extend below root and be trimmed by 3D ground. |
| generic_knight_01 | Mini heavy armor | Shield/mace; simplified gait and minor contact trimming. |
| generic_beast_01 | Mini stone creature | Low crouched silhouette, subtler front/back difference. No enlargement. |
| generic_caster_01 | Mini caster | Complete support cycle; upper-body angle/cape seam remain. |
| generic_archer_01 | Mini archer | Complete gait; front view is more frontal than diagonal. |
| generic_bandit_01 | Recovered original Turbo bandit | Original verified source; 35 weighted ticks; no regeneration. |

Exactly `ch01_bandit_a`, `ch01_bandit_b`, `ch01_bandit_c` additionally resolve to `generic_bandit_01`. There is no prefix/wildcard rule. Their names, AI and stats belong to the chapter author. Each actual unit ID owns its loader binding, movement phase, facing, position, health and action state. Sharing immutable image textures does not share motion clocks. This branch does not itself add the first-chapter encounter.

All six profiles use 160×160, root (80,144), two direct left views and mirrored right views in static idle and movement. One held idle and eight weighted walk frames complete one cycle per grid of actual travel. No per-frame recenter, shrink, speed change or depth-disable. All 108 PNGs are unchanged from source commits e9b58c9 (soldier), c315950 (four-package batch), c7747fa (bandit). External task metadata is omitted from consumed receipts. Old hero art remains untouched.

## Combat and fallback

No generic portrait or side-view attack/hurt art was supplied. Portrait UI therefore uses its existing blank/initial fallback, never another character's face. When an authoritative attack involving an admitted generic has no authored cut-in, `view/generic_attack_feedback.gd` shows the actual attacker/target names and damage on the map, with a brief strike cue (suppressed by reduced motion). The event queue holds the target and action lock until feedback finishes, then settles authoritative HP/death. Ordinary polls do not replay feedback; skip clears it. Existing authored character cut-ins retain priority and timing. This is usable gameplay feedback, **not** a claim of complete authored generic combat animations.

Ordinary sequence loading still rejects generic IDs unless catalog admission is requested. Canonical guards and paths are bounded to the same identity. Malformed motion retains that identity's static neutral; missing canonical art uses the existing non-identity placeholder. Unknown Mod IDs do not inherit generic art by class resemblance.

## Verification scope

Integrity checks decode/hash all 108 PNGs and validate all six manifests. Actual scene fixtures cover four facings, fixed/3D backgrounds, 1280×800/960×600, ghost/root/HP, pause/turn/stop/skip and retained fallback. Real touch attacks cover each template as attacker and defender, lethal hold/settling, repeated input, busy locks and skip. Three separate mountain-bandit instances perform an actual Lua AI turn in order with visible feedback; the editor's existing ID field is exercised without balance mutation. Real authority/client movement and attack tests cover polling replacements. Tests use fixtures; production chapter content is unchanged.

Linux only. Full-body art style, sliding, angle and sole-trimming limitations remain. No media, source videos, paid jobs or chapters 4–8 are introduced.
