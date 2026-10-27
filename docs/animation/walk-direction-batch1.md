# Second bounded three-pose walk candidate

Base: main `22af7e8be5758d8641ae423b0e3d3d35c24d2b2f`.
Runtime remains N/L/N/R, actual distance / one world grid; source neutral is reused exactly. No new runtime movement code, per-frame offsets, IK, root bobbing, speed changes or rescaling. Oren retains the accepted map-only 1.05 multiplier.

| Newly registered direction | Engine review finding | Remaining limitation |
| --- | --- | --- |
| Finn back_right | Correct world -Z lookup, connected opposite advancing legs, stable bow hand; both steps and stop visible | Restrained upper body, held-pose sliding; source phase relabel is recorded by artist |
| Oren back_left | Correct world -X lookup, sword/shield ownership retained, no whole-body jump | Minor pose/colour variations, sole contour 117/119 |
| Oren back_right | Flagged candidate reviewed separately on actual road/bridge route; connected legs, stable equipment, no disappearing character/feet observed | Sole contour 120/116 and raised-foot beat remain visible; not rejected solely by bottom coordinate and not claimed physically locked |
| Mara front_right | Correct world +X lookup, readable opposite steps, same neutral at rest | Small source pixel/head-edge differences and held-pose sliding |
| Bram front_right | Readable opposite steps, hammer remains in the same hand, no size change | Slight brighter/sharper step-frame palette relative to N remains visible |

These are engine-qualified **review candidates**, not blanket acceptance of all eight characters or four directions. Combined with the prior two directions, seven clips are registered: Finn FR/BR, Oren FR/BL/BR, Mara FR, Bram FR. Finn FL/BL and Oren FL remain held and are not registered. Neri, Tessa, Adela and Elsbet retain static movement in all directions. Missing clips safely use current directional N; existing idle loops remain separate.

## Evidence and reproduction

- Art inputs: `8d3d3408a637a140408234793d82be33dee795ff` and `17982d7cb46b73b68c1cf8689fd987c619d66755`. All candidate N/L/R SHA256 identities and RGBA 96×128 canvases verified. Original source manifests remain unmodified provenance, including their pre-engine-review status.
- `tests/walk_rear_fixture.gd` supplies explicit legal test placements and temporarily makes the test actor player-controlled with movement 3. No default content or faction change ships.
- Real command routes: rear-right (4,8)→(4,5), rear-left (4,8)→(1,8), front-right (1,8)→(4,8). Their authoritative paths are consumed by the production UnitMotion. Five normal-speed sequences were captured at 1280×800 fixed background and 960×600 original 3D, with original depth testing, lights and shadows. Movie capture uses 30 simulated FPS; capture wall-clock FPS is not a hardware benchmark. Review media is Library-only, never Git.
- `tests/test_walk_direction_batch.gd`: exact textures by direction and quarter-distance, real legal corner commands, root/HP bounds, idle priority, stop/skip, unchanged snapshots and held-direction fallback; 665 checks. Also executed with an actual 960×600 viewport while switching both renderers.
- `tests/run_walk_network.py` now accepts test-only `AMBER_WALK_ACTOR` and `AMBER_WALK_DIRECTION`. Each registered new direction is run against a separate real fsnet authority to observe ordinary runtime replacement without gait replay. The client deliberately uses half presentation speed to sample many polls, without changing rule speed or cadence.

Existing environment vegetation can occlude feet in original 3D; no depth bypass or per-frame correction was introduced to hide this. Mild held-image sliding, source palette variation and tiny edge clipping remain limitations of the accepted simplified method. Independent review of the exact candidate is required before main integration.

## Validation checkpoint

The full available suite passed 7,630 counted checks, five existing three-process network variants, target-confirm network UI checks, and six actual-authority gait cases (previous Finn FR plus the five new directions). Each gait case observed 31 ordinary runtime replacements without replay. Actual 1280 fixed-view capture passed 1,115 assertions; 960 original-3D capture passed 1,385. Actual graphical direction/turn/HP tests passed 665. Normal-speed turn diagnostics additionally checked held-facing neutral on mid-segment skip; skip intentionally retains its existing interruption-facing behavior rather than inventing the final path-facing. These results do not constitute Windows visual runtime verification.
