# Four-actor front-right walk candidate

Base: accepted main `f4cad8b25fb2d2ffe7da0163588c3edcc4f97773`.
Art input: `1fe1572d4f4d9366cc37188cc8ff2ff8d7f3b1c0` (8 PNGs, 4 manifests).

This bounded candidate registers Neri, Tessa, Adela and Elsbet front_right. Existing seven clips, Oren's map-only 1.05 multiplier, default roster, rules, native libraries, movement speed and combat remain unchanged. Eleven of the eventual 32 actor/direction clips are registered; other directions still use their exact current neutral image. This is not completion of four-direction animation for all eight actors.

All four use three unique images, N/L/N/R, one full cycle per actual world-grid distance. Neutral paths and hashes are preserved. Reserve actors use their `assets/characters/reserve/<id>/map/front_right.png` rather than a role-based substitute. No per-frame offsets, image corrections, IK, body bounce or new movement code were introduced. Original artist manifests retain their pre-engine-review status as source provenance; findings below record this separate engine review.

| Actor | Actual-map finding | Retained limitation |
| --- | --- | --- |
| Neri | Opposite steps readable, staff stays in the same hand; stable rule root and neutral return | Small cloak/head-edge and shading variations; right sole is higher than neutral |
| Tessa | Alternating boots and connected legs readable; dagger ownership retained | Right source sole reaches y120; tiny edge clipping remains possible with original ground depth |
| Adela | Reserve ID selects correct portrait/map profile and gait; spear/shield retained | Left step is more extended and sole ends at y116 vs neutral119; visible stance variation, not compensated |
| Elsbet | Reserve ID resolves correctly; alternate boots visible below skirt and staff remains stable | Skirt hides much of the hip/knee chain; y120 right sole edge and restrained upper body remain |

No whole-foot disappearance or whole-body jump was observed at normal map size in the sampled routes. This does not claim zero foot sliding, full anatomical visibility under skirts, or pixel-perfect registration. Four held beats naturally retain some sliding between pose changes. Original 3D vegetation may occlude boots; depth testing was preserved.

## Validation method

`tests/walk_rear_fixture.gd` supplies clearly labelled test placements. Adela/Elsbet replace an existing unit ID only in test content, retain an existing legal role and do not enter the shipped roster or acquire a new profession. Test story events are empty to avoid unrelated original-ID references. Production content is unchanged.

Actual Lua move commands traverse (1,8) to (4,8). Production UnitMotion consumes the authoritative path at unchanged speed. A separate real corner command to (2,7) checks direction switching, whole-grid neutral, missing-direction fallback and skip. Tests check cached HP width against every displayed gait texture, fixed foot anchor, MapIdle exclusion, snapshots and stop behavior.

Normal-speed review: actual 1280x800 fixed-background capture, 12.53 seconds / 376 frames at 30 simulated FPS; 892 assertions. Actual 960x600 original-3D route capture: 1,108 assertions. Software movie capture ran slower in wall time; the on-screen FPS is not a device-performance benchmark. Review screenshots and video are native Library deliverables only, not repository media.

The direction/turn suite also ran with actual 960x600 and 1280x800 viewports, switching both renderers in each: 1,193 assertions each before adding nine explicit registration-presence checks. The final suite includes those nine extra assertions. Network fixtures resolve the actor index after reserve-ID substitution and match the separate authority's content; production Session/network code is unchanged. Every new clip is tested against a real fsnet server with ordinary Runtime replacements and no gait restart. That network diagnostic uses half presentation speed to observe more polls, separate from the normal-speed visual capture.

Linux Godot 4.6.3 / llvmpipe Compatibility only. Windows DLLs and native source are unchanged; Windows visual execution has not been tested here. Main integration remains gated on independent review of the exact candidate.

Final checkpoint: full `tools/test.sh` passed 8,158 counted assertions, five three-process network variants, target-confirm networking, and ten actual-authority gait cases. Each gait case observed 31 Runtime replacements with no replay; Adela/Elsbet used their own profile IDs. The final presence-assertion addition was rerun separately: 1,202 direction/turn checks passed. Both graphical viewport runs passed their 1,193 checks. No production runtime code change was needed beyond the four registry entries.
