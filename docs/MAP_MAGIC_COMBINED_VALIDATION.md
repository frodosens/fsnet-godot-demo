# Combined hybrid magic candidate (not a main/release update)

Inputs: verified main `db7176eed5bfee679d330a895f2861339f9144df`
(tree `5253b3049ab44cd2d418b29c49367064306b23c1`), complete map magic base and
visible HP correction through `ff24806`, hybrid runtime `7459ff3`, and authored
atlas commit `f5bc83174fff42b39b7c8e30aa4be498beaef318`.

Prepared only on `work/map-magic-hybrid-combined`. Local/remote main were not
modified. The two merge conflicts were additive HUD node registration in
`main.gd` and the test list. Both magic and generic feedback nodes/tests are kept.

## Result

The core now loads all three admitted atlases as 4 cast + 4 travel + 8 impact/fade
frames, `authored_sheet=true`. All PNG hashes match the supplied contract; no art
bytes were edited. SpriteFrames/AnimatedSprite2D core, AnimationPlayer timing,
and real CPUParticles2D auxiliary layer are active. Measured focus charge/travel
art gets a local (0,-8px) offset; centered impact frames do not. The smaller heal
silhouette gets 1.3x presentation scale. Original pivots and transparent margins
remain in the source art.

Exclusive event order is: recognized existing magic/heal -> map timeline;
supported physical attack -> cut-in; otherwise admitted generic physical attack
-> generic map feedback. Each branch returns once it owns the event. Queues wait
for the correct owner and clear all owners on skip/gap. Existing story head
bubbles, three-bandit identities, Neri standing idle, XP and details are retained.
The visible bottom dock and map HP both use the event queue's impact projection.
No Lua/gameplay changes were made relative to the verified main input.

## Verification

- Atlas audit: 111 checks; dimensions, RGBA, SHA256, margins, all 16 frames nonempty
  and distinct within their actual stages.
- Hybrid and routing: map magic 64, combined routes 27, particle pool 31,
  SpriteFrames/AnimationPlayer 36 checks. Authored core diagnostics are 4/4/8 for
  all three effects. Real generic recipients receive magic once, Neri physical
  basic attack retains the cut-in, and generic physical attacks retain fallback.
- Regression: generic combat 146, instances 33, runtime 8173, AI 768, turns 78;
  homeward bandits 116, contract 421, routes 96, scene 124, review 43;
  Neri standing idle 192; attack feedback 66; bottom dock 54; event sequence 513;
  mobile targeting 108; story footer input 55; progression 72; character details
  UI 86 and progression 49. All passed through the checked runner.
- Real three-process magic network probe passed: both scene clients receive an
  actual focus_bolt, one reconnects mid-flight, each displays one impact and
  matches final authoritative state. The separate homeward three-process
  disconnect/reconnect regression also passed.

The actual 26-second movie-mode demo uses raw touch/key input to select each
existing skill, preview/confirm a target, attempt a blocked in-flight duplicate
input, and switch actor after effects finish. Test arrangements and fixed 30fps
capture are labelled. It is Linux OpenGL/Mesa rendering, not Android hardware or
performance evidence. Demo files stay outside Git and are delivered via Library.

Capacity remains 17 particle nodes / 336 configured particles, <=0.55s lifetime,
plus nine core sprites and one AnimationPlayer. This is a resource bound, not a
measured Android budget. Independent candidate review is still required; this
validation does not authorize main mutation or release publication.

Earlier docs describe historical fallback checkpoints. This document supersedes
their pending-art status for this combined candidate.
