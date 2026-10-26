# Environment, animation and Mod network increment — 2026-10-26

This is a tested playable increment, not a release-art acceptance. Previous UI v2 main is `7d15f182`; source art commits are `7cd96435` (bow/magic), `4b7f56fa` + `c8bf44b3` (old-view gait candidates), `4f1fab83` (environment), `04de8a47` (Mara elevated proof). Original assets/provenance remain intact.

## Implemented

- Environment albedos with neutral white base, rough matte material, world-space texture projection and nearest mip sampling. Selection/reachable highlights are separate geometry, not darkening albedo multiplication. Original simple geometry now has a pitched inn roof, timber supports, bridge rails and a shallow stepped arch side. Dirt terrain D is traversable and editable. Grass still looks dense; wall repeat seam remains an art follow-up.
- Manifest-driven real walk poses plus path interpolation, idle return, skip and authoritative-step interruption. Selection ring follows the visual actor. Missing directions do not silently use old flat poses. User's latest elevated four-view requirement supersedes the old cardinal art. Mara currently has four elevated idles and ONE real walk direction; this is not six complete animated characters.
- Three attack presentations: Mara sword thrust, Finn arrow release, Neri focused magic, all against Oren's available hit/recovery poses. Eight unique attacker frames held on a 24-tick timeline; separate projectile/impact layers. Not 24 unique frames. Shared Lua settles the result before animation. Skip/speed/new steps never modify rule state.
- Network menu selects validated built-in or user Mod content. Command-line authority accepts `AMBER_MOD` using the same validation. Rules/content mismatch rejects joining. Matching custom Mod survives real disconnect/replay tests.

## Verification

`tools/test.sh` passed: 382 counted assertions, scene input smoke, 20 content-budget repetitions, and three independent server/two-client OS-process scenarios (basic; equipment/items/mobile-cast reconnect; same with custom content). Raw output: `validation/art-animation-runtime.txt`. The Mod fixture changes static content while retaining the same final dynamic numeric snapshot; static content is separately bound by the handshake hash.

Local microbenchmark: 16 AI on 16x16 board, move budget8; Release native bridge, Godot4.6.3, Lua5.4.7, AMD EPYC9V74 shared Linux host (5CPU affinity). Twenty fresh rule executions: p50 8525us, p95 10708us, max12322us; snapshot1013bytes. This is not transport throughput or a production latency SLO, and this run overlapped software-rendered capture.

Actual rendering used X11 dummy display and Mesa25.0.7 llvmpipe LLVM19.1.7 OpenGL4.5. Four directional screenshots come from legal ordered movement and validate texture selection without rule mutation. Godot MovieMaker captured:

- `tests/record_iso4.gd`: 177 frames/5.9s at fixed30fps; one actual right-front move, then an explicitly presentation-only four-idle turntable. Recorded in20s on the software renderer. Hash `43d4c471c182141f148fd3d6cef46b28e4d0edfe3acd368931e1ebd6f03f1dcd` unchanged during playback.
- `tests/record_battle.gd`: 270frames/9s, three real legal attacks in small explicit fixtures. Recorded in28s. Runtime30fps performance is NOT established by offline fixed-fps capture. Logs retain each settled hash.

Reproduce with the same XDG directories as normal tests and a working X11 display:

```sh
godot --display-driver x11 --audio-driver Dummy --rendering-method gl_compatibility --path . --write-movie /tmp/iso4.avi --fixed-fps 30 --script res://tests/record_iso4.gd
godot --display-driver x11 --audio-driver Dummy --rendering-method gl_compatibility --path . --write-movie /tmp/combat.avi --fixed-fps 30 --script res://tests/record_battle.gd
```

## Remaining gates

Other five roles' elevated idles and all remaining elevated walk directions; full defender/attacker combat sets; smoothness and foot-contact refinement; consistent portrait/character/environment palette; grass frequency and stone-wall seams; more scene dressing without obscuring the grid. No complete idle breathing/turn animations or all-role death/recovery set is claimed. Network remains loopback-only, no account ownership, durable room recovery, public multiplayer acceptance, cross-platform deterministic certification or exported release binary. Content editor and equipment are bounded functional samples, not commercial content volume.
