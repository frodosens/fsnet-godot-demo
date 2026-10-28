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

`ui/battle_cutin.gd:consume` intentionally admits only Neri's ember/focus_bolt
art, not her ordinary physical attack. `view/event_sequence.gd:play_next`
previously applied unsupported attacks immediately when no cut-in started.
This made a real spent action look like nothing happened except an HP change.
Unsupported Mod identities had the same missing-feedback route.

No automatic actor change was reproduced. `Runtime.usable` does not exclude
units merely because their action was spent. `main.gd:wait_selected` advances a
spent actor only on explicit Wait; selection can also change on a deliberate
ally tap or when the selected actor dies / the battle ends. This investigation
does not claim to explain every instance of the user's reported switch.

## Narrow candidate

Attacks without an admitted authored cut-in show their event's actual damage
(or critical result) in the existing map feedback layer for its normal 0.75s
lifetime. The visual queue waits for that feedback, so repeated taps, Wait and
reselection cannot overtake it. Authored melee/ranged/magic cut-ins are retained;
ordinary physical attacks are not relabelled as spells. Skip clears feedback and
settles to authority. Same-step Runtime replacement does not replay it.

The rule source cannot currently emit ordinary attack misses or zero damage:
it clamps damage to at least one. High-armor and lethal attacks were exercised
with real Lua commands; zero feedback is only a synthetic defensive display test,
not a claim of a gameplay miss mechanic. Invalid/out-of-range/dead targets do not
spend an action or generate damage feedback.

## Validation

- Focused regression: 59 checks, including mobile second-tap, move then attack,
  explicit Wait, dead/invalid/range, lethal visibility, armor minimum damage,
  pending poll vs command-busy, same-state replacement, skip and no duplicate.
- Real authority/client test: 328 sampled checks, five Runtime replacements
  during Neri feedback; canonical result equals offline, no replay/auto-next.
- Existing sequence/input, Wait, targeting, sides, mobile, abilities and rules
  checks remain applicable. Tests are in the normal test list.
- Linux Godot 4.6.3 compatibility renderer / llvmpipe; actual viewport touch
  injection and screenshots at 2400x1080 and 1280x800. This is not Android-device
  testing. Verification screenshots remain outside Git.

The entire reported symptom is not declared solved: automatic switching still
needs the particular actor/input sequence if it occurs independently of Wait.
