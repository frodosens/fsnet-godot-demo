# Attack feedback investigation — local candidate

Baseline: fe82667781852f6cc37b8097525bfaad7d9454ab. Chapter 4–8 drafts were
not used or modified. No rule, native, actor-selection or party-picker code changed.

## Reproduced

`tests/probe_attack_feedback.gd` uses validated unique-position content and two
real InputEventScreenTouch taps through the viewport (first preview, second
confirm), at 2400x1080. On the unchanged baseline:

| Actor / ordinary attack | Oren HP | Action spent | Event | Cut-in / other feedback | Selection |
|---|---|---|---|---|---|
| Mara | 6 -> 2 | yes | attack, damage 4 | cut-in | Mara remains |
| Finn | 6 -> 3 | yes | attack, damage 3 | cut-in | Finn remains |
| Neri | 6 -> 3 | yes | attack, damage 3 | none | Neri remains |

`ui/battle_cutin.gd:consume` filters Neri to ember/focus_bolt and omits
ordinary attack's event ability `attack`. The eight existing Neri staff-release
poses, projectile and sockets are present and load successfully; this is a
presentation whitelist omission, not missing art or missing authoritative damage.
`view/event_sequence.gd` immediately settles an event whose cut-in is rejected.

No automatic actor change was reproduced. `Runtime.usable` does not exclude
units merely because their action was spent. `main.gd:wait_selected` advances a
spent actor only on explicit Wait; selection can also change on a deliberate
ally tap or when the selected actor dies / the battle ends. This investigation
does not claim to explain every instance of the user's reported switch.

## Narrow candidate

Add `attack` to Neri's cut-in whitelist. Reuse the existing staff release,
projectile, impact and recovery at existing timing. No edits to Lua, native code,
selection, input routing, event queue, shared hashes, or damage type: ordinary
attack remains physical. No new map-number fallback is retained in this candidate.
Existing mirroring, skip and same-step replacement behavior applies unchanged.

The rule source cannot currently emit ordinary attack misses or zero damage:
it clamps damage to at least one. High-armor and lethal attacks were exercised
with real Lua commands; no gameplay miss or zero-damage mechanic is claimed. Invalid/out-of-range/dead targets do not
spend an action or generate damage feedback.

## Validation and reproduction

- `godot --headless --path . --script tests/test_attack_feedback.gd`: 66 checks.
  Real viewport touch preview/confirm, repeat/orphan touch release, emulated mouse,
  Wait/confirm hit rectangles, no auto-next, invalid/dead/range, minimum damage,
  move/attack/Wait, pending poll, command busy, replacement and skip.
- `python3 tests/run_attack_feedback_network.py`: real authority/client, 655
  checks and 10 Runtime replacements while Neri cut-in runs; same offline result.
- `godot --headless --path . --script tests/test_ranged_animation.gd`: 26 checks;
  adds a legal Neri ordinary attack, opposite viewer side, mirrored impact socket
  and authority preservation to existing ranged/magic release-impact tests.
- Baseline reproduction: `tests/probe_attack_feedback.gd`.
- Graphical repeat uses the same focused script, `ATTACK_SMALL=1` for 1280x800,
  otherwise 2400x1080. `ATTACK_CAPTURE=/tmp/example.png` saves local evidence.
  Linux Godot 4.6.3 / llvmpipe; not Android device testing. Media stays outside Git.

Only the no-animation defect is reproduced. Duplicate touch releases, touch
emulated mouse, and a release at Wait without a paired press do not switch actor
in the exercised path. Genuine explicit Wait still advances correctly. These
checks do not establish the cause of every reported automatic switch.

Local review candidate only; no external publication is authorized for this step.

Final related regression: 3,501 checks across 12 existing sequence/input/Wait/targeting/
combat-side/mobile/item/ability/logic groups, plus 26 ranged checks. Focused 66 checks
passed headless and in actual 1280x800 and 2400x1080 windows. Full project suite
was not rerun for this one-line production admission change.
