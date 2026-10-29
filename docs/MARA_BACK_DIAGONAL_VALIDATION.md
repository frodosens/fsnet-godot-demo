# Mara rear diagonal walk candidate

Base: reviewed/frozen `a6da83a74e97fde85b1188646c426e30227a0486`.
Art input: `f9a445fac43f0f236879cc22306097eac8ffe4b7`.
Isolated branch: `work/mara-back-diagonal-fix`; no main mutation.

Only the current Mara profile's `back_left.motion` and `back_right.motion`
objects were replaced. The art package's full runtime manifest is retained as
provenance, not installed wholesale. Front motion, idle, guards, and every other
profile field match the frozen base. All eight PNG hashes match the admitted art.
The later source keys are 52/55/58/61/64/66/70/72, endpoint75; holds are
3/3/3/3/2/4/2/3 (23 ticks). Canvas160x160, root(80,144), no per-frame offset.

The actual source faces upper-right: right motion is raw, left motion mirrored.
Existing idle art faces left and keeps its original mirror values. The former
validator incorrectly required identical idle/motion flip flags. An explicit
motion `source_facing` now permits either source within the same front/back pair;
expected mirror is checked against that source. Absent metadata retains the old
left-source rule. Invalid pair or wrong mirror still rejects the profile. Runtime
renderer already uses each clip's flip independently and required no changes.

Verification:
- New real-scene regression covers both upward screen routes in both backgrounds,
  all eight frames and weighted cadence, stable roots, same-step refresh, natural
  stop, idle facing changes, skip, legal rear corners, and unchanged Lua state.
- Hero refresh contract29, scene4512, edges45; Rodd motion44/scene1504;
  Neri standing idle192; generic runtime8173; map spell core36 checks passed.
- Hero source audit270 checks passed. Its old path assertion was updated for the
  already-shipped Neri standing idle as well as this Mara replacement.
- Four real server/client walk runs passed: fixed left/right and 3D left/right.
  Each observes >=29 Runtime replacements, all eight motion poses, no phase
  restart, correct mirror, authoritative endpoint, and stable stopped idle.
- Before/after real Godot movie capture uses legal fixture moves in both
  backgrounds, labelled 2x movement and fixed30fps. Capture is outside Git;
  Linux software renderer is not Android performance evidence.

Independent review required before any main update. This does not include the
ongoing battle-unit abstraction work, new art generation, or gameplay changes.
