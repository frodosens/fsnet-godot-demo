# Map magic candidate

Base: reviewed combined candidate `d60f127dd5660b531b6b940990a05be436c8fa67`.
This branch has not been merged to main or independently reviewed.

## Audited routing

Lua emits damage as `kind=attack`, `ability`, `actor`, `target`, `damage`,
`hp`, `is_critical`. Damage type is resolved from that event's ability ID in
its batch content. `attack` is physical, including Neri's staff basic attack;
`ember` and `focus_bolt` are magic. Existing melee and ranged physical cut-ins
are retained, including Neri's previously repaired basic-attack presentation.

Healing emits only `kind=heal`, `actor`, `target`, `amount`. It does not identify
its ability, area center, or item. All existing heal events receive the same
neutral restorative cue; this does not claim rally/bandages are magical damage.
No Lua, native extension, content, damage type, skill, or balance changes.

## Implementation

`view/map_magic.gd` consumes the existing event queue. It draws a projected rune,
existing runtime gather/charge/bolt/impact/dissipate textures, target flash and
actual result numbers. The 1.35-second timeline applies **presentation HP only**
at 0.62 seconds. Consecutive distinct recipients of the same Neri ember within
one command batch share a cast and impact; repeated hits and command batches are
not merged. Only recipients named by Lua receive impacts; empty radius cells and
an unreported area center are not inferred.

Map meters and HUD HP use the queue's HP projection. Dead actors and their shadows
remain until impact. Actual authoritative HP/MP/cooldowns/RNG are already settled
and never changed by the presentation. Input stays gated for the entire queue.
Skip restores latest truth, clears effects, and restores camera pan. Same-step
refresh/replay does not restart effects; snapshot gaps discard stale effects.

Camera focus uses the existing cropped mobile authored-map pan limits, with a
maximum 0.025-world-unit impact shake and restoration of the previous pan.
Desktop/uncropped and unsupported maps keep their framing. Reduced motion keeps
runes, results, and timing but removes travel, flash, focus and shake. Toggling it
during a cast also releases the camera. Unknown/unmodified spell routes are not
silently generalized from a mage role.

## Validation on Linux Godot 4.6.3

- `tests/test_map_magic.gd`: 44 checks, real shared Lua commands: three-target
  ember, lethal target, impact HP, physical Neri basic attack, focus-bolt MP,
  wounded rally and bandage, reduced motion, raw touch input blocking, queued
  enemy turn, same-step refresh, skip, reconnect gap, authored camera limits.
- Existing event sequence 513; attack feedback 66; ranged animation 26; combat
  context 6; abilities 11; items/AI 10; target confirmation 42; mobile targeting
  108; selection camera 79; active actor marker 247; character details UI 86:
  all passed through `tools/run_checked.py`.
- `tests/run_network.py`: real fsnet server plus two clients in three processes,
  disconnect/reconnect, identical final state hash. This is the existing network
  regression, not a new live multiplayer visual acceptance scenario.
- `tests/record_map_magic.gd`: reproducible actual OpenGL/Mesa llvmpipe capture of
  cast, travel, impact, and settled states for ember, focus bolt, and healing.
  PNG output is `/tmp/map-magic-*.png`, deliberately outside Git. Screenshots are
  staged timeline samples, not continuous real-time video or performance evidence.

Native test build uses external pinned godot-cpp 507ed9d, Lua 5.4.7, and local
fsnet headers with matching `/workspace/fsnet-env/cmake-build/libfsnet.so`.
The older saved release fsnet library did not match current header ABI and was
not used for the successful tests. No compiled binaries are included.

## Limits

Existing small cyan FX are reused for both Neri spells; this is a functional
presentation candidate, not newly authored per-spell final art. No Android device,
Windows runtime, real touch hardware, or GPU performance acceptance was performed.
No formal art assets were generated, so there is no new formal art package to
back up. Independent review and approval remain required before a main merge.

## Independent-review correction: visible bottom dock

Review found that the original candidate projected the legacy HUD but left the
visible `ui/bottom_dock.gd` reading settled authoritative HP. The follow-up routes
both visible dock meter and numeric text through `presented_hp`, including the
impact callback (not just the next layout refresh). Rules remain untouched.

Delta validation: map magic 64 checks (20 added), bottom dock 54, event sequence
513, attack feedback 66, character details UI 86; all passed. New cases check
visible dock HP before/travel/impact, an authoritative damage command followed by
a queued heal, selection lock/resumption, ordinary same-step VM replacement and
reconnect gap settlement. Snapshot identity is checked throughout.

`tests/run_map_magic_network.py` additionally passed with a real fsnet authority
and two independent main-scene clients. A real network `focus_bolt` reaches both
map timelines; ordinary polling replaces their VMs during travel; the driver
reconnects during travel. Each reports exactly one impact and the same final hash
`da60d7fe33efc59715d9c7d0ffb94199e50675e90906b0d69802442d7b500093`.
This runs actual presentation nodes headlessly; it is not GPU/network-video proof.

A separate 26-second Godot movie-mode demo uses raw touch/key events for selection,
skill picker, target preview/confirmation, an in-flight duplicate touch, and
post-effect selection. Test arrangements and fixed 30fps capture are labelled;
this is not hardware performance evidence. Demo script/video remain outside Git.
The original pre-correction demo is superseded and must not be delivered.
