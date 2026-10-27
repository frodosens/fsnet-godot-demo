# Mara and Bram rear-facing walk candidate

Base: accepted main `bad7f355c0bc65a77b0a9bf22fec17281b98a714`.
Art input: `11c33e7208890a278a5028a903975f6034b9f918` (eight PNGs and four manifests, failed original frames excluded).

Four registered candidate clips: Mara back_left/back_right and Bram back_left/back_right. The previous eleven entries are unchanged; fifteen of 32 eventual actor/direction clips are available. Missing directions remain static neutral fallback. No actor scale, movement speed, neutral images, rule content, native binaries or combat resources changed. Oren's map-only 1.05 factor remains unchanged.

The existing player consumes N/L/N/R at one cycle per actual grid distance. All source neutral hashes match current runtime assets. There is no new movement implementation, per-frame translation/scale, IK, body bobbing or depth bypass. Artist manifests remain unchanged provenance, including their pre-engine-review flags; this document records the subsequent runtime gate separately.

| Clip | Engine review | Limits retained |
| --- | --- | --- |
| Mara back_left | Opposite steps and unchanged sword/shield hands readable on the actual road; root and torso do not jump | Left sole115 vs right119 produces visibly raised-foot/shorter contact beat; not a physically planted-foot claim |
| Mara back_right | Correct -Z facing, readable alternate steps; neutral restored at stop | Soles119/117; small knee-plate/palette and upper-edge changes remain |
| Bram back_left | Opposite connected legs readable; hammer hand remains occluded by torso consistently | Soles114/119 give the strongest lifted-foot beat of this batch; no bottom-alignment correction |
| Bram back_right | Both steps readable with hammer ownership unchanged; stable normal map scale | Soles118/118, small shading/contour changes and restrained upper body |

All four qualify for independent review under the accepted simplified held-pose gait, not physical zero-sliding animation. No whole-foot disappearance or whole-body hop was observed in sampled views. Ground/vegetation depth was preserved. Foot elevation differences remain visible and are not hidden by compensating transforms.

## Actual-engine evidence

- Explicit legal test placements, not default campaign footage: (4,8) to (1,8) for back_left; (4,8) to (4,5) for back_right. Commands and paths come from Lua; the production UnitMotion player consumes them.
- Four normal-speed routes at 1280x800 fixed background: 892 checks, 376 frames / 12.53-second movie at 30 simulated FPS. Movie recording takes longer in wall time under llvmpipe; onscreen FPS is not a device benchmark.
- Same four routes at 960x600 original 3D: 1,108 checks. Actual screenshots were inspected for source pose coherence, grounding, light/shadow and foot clipping.
- Normal-speed legal corner routes (4,8) to (3,7), Mara and Bram: 302 checks, actual facing lookup and held interruption-facing neutral on skip. No invented animation path.
- Extended direction suite covers every registered batch clip, both scene modes, legal corners, cached HP width, canonical neutral, idle exclusion, skip, snapshots and static fallback. Executed with real 1280x800 and 960x600 viewports.
- One legacy Mara idle test assumed every backward move stayed static. Its assertion now checks the actual registered distance sample while retaining the idle-clock-reset and final-neutral assertions. No production change was needed.
- Real fsnet authority/client gait diagnostics cover each newly registered direction, including ordinary Runtime object replacements without travel reset or replay. These diagnostics use half presentation speed to sample polls; visual captures use normal speed.

Review screenshots/video stay in native Library, never Git. Linux Godot 4.6.3 / llvmpipe Compatibility was tested; no Windows visual-runtime claim. Exact candidate requires independent review before main integration.

Final validation: 8,699 counted full-suite assertions, five three-process network variants, target-confirm networking and fourteen real-authority gait cases passed. Each gait case observed 31 Runtime replacements without replay. Both actual graphical viewport runs passed 1,734 direction/turn/HP checks; normal-speed straight-route captures passed 892/1,108 and corner capture passed 302.
