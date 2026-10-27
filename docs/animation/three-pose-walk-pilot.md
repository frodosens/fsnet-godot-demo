# Distance-driven three-pose walk pilot

Candidate scope: Finn and Oren, `front_right` only. All other directions and units retain their current directional neutral image while moving. This is not completion of the eight-character/four-direction asset set. Combat, rules, input confirmation, native libraries and content are unchanged.

## Binding and calibration

`assets/animations/walk_cycles.json` binds a unit ID and one of the existing four diagonal directions to `neutral`, `left`, `right` PNG paths. The renderer plays **N/L/N/R**, four equal quarters, with **three unique drawings**. N must be the actual directional idle phase-zero texture already in use. The loader rejects a clip if that neutral does not match, including when a Mod reuses the ID with different art. Legal custom IDs are supported; unregistered IDs/directions use the old neutral fallback.

`cycle_distance` is explicitly 1 world/grid unit. UnitMotion accumulates distance between its actual previous and next world positions, not wall time, frame count or character scale. Existing movement is linear: fixed reference background 1.25 world units/s (0.8 s/grid), original 3D 1 unit/s (1 s/grid). Speed changes naturally change both travel and cadence. Full grid boundaries return N; new events reset travel, duplicate steps do not restart it, and finish/skip restores the same neutral before idle resumes. MapIdle already yields to an active motion. There is no IK, sprite deformation or root bobbing.

PNG loading is cached once in the shared library. Invalid manifests/entries are rejected atomically with diagnostics in `WalkLibrary.errors`; no per-frame file reads or alpha scans. A registered clip's images join the existing startup-only conservative overhead-health-width calculation. No frame-dependent meter resizing is introduced.

## Asset method and limits

Generate L and R independently from the **same approved N**, retaining identity, head, cape, hands and equipment. Do not generate a new N to disguise drift. Confirm anatomical leg identity from the hip connections; do not infer anatomy solely from screen left/right. Finn carries the bow in his anatomical left hand; the upper body is deliberately restrained, not a fully animated counter-swing. Additional arm-swing experiments were rejected.

The source PNGs are unchanged from the approved v5 diagnostic. Finn R has opaque pixels through source y=120. Earlier normal-depth 3D probing found up to one screen row of ground clipping at a sampled 1280 position; sampling/foreground vegetation affect visibility. Depth testing remains enabled. Mild held-pose sliding and small pixel variations remain; this is not a physical foot-lock solution. Oren repeats the method from the same canonical-neutral source for both steps. His L sole outline ends at y114 versus R y120: actual-map review shows a higher foot silhouette in the L beat, which remains an explicit visual acceptance limitation rather than being hidden with root translation. Each additional character/direction still needs actual-map review before registry admission. Do not treat the pilot as unattended batch-production proof.

## Reproduction

- `godot --headless --path . --script res://tests/test_walk_cycles.gd`: manifest validation, distance phases, zero/fast speed, repeated/new events, turn fallback, SceneTree pause, finish/skip, idle ownership and HP bounds.
- `python3 tests/run_walk_network.py`: separate actual fsnet server and game client; normal polling replaces runtime objects during movement without restarting distance/poses.
- `bash tools/test.sh`: existing rule/UI/network regression plus these tests.

Graphical evidence is delivered through native chat, never committed. The candidate clip uses a clearly labelled legal test placement, Finn (1,8) to (4,8), at unchanged speed. Fixed-FPS software movie capture is not a hardware performance measurement. Linux Godot 4.6.3/llvmpipe is the tested renderer; no Windows visual runtime claim.

## Candidate verification checkpoint

Both Finn and Oren were rendered on the same legal three-cell path in 1280×800 and 960×600, in fixed background and original 3D: 72 movement ticks at 30 simulated FPS fixed, 90 in 3D, unchanged authoritative endpoints/snapshots. Oren's labelled test fixture temporarily makes him player-controlled with three movement cells; this is test data, not a shipped faction/stat change. Both normal-size sequences retain readable equipment and identity, with held-frame slip; Oren's higher L-foot silhouette remains subject to parent visual review. Neither y120 sole is certified free of all depth clipping. No production depth bypass is used.

Full available suite: 6,644 counted checks, five existing three-process network variants, target-confirm network UI test, and added server/client gait test (31 ordinary runtime replacements during travel, no restart). Python registration test covers square normalization/determinism, non-square rejection, invalid threshold/suffix and overwrite/symlink protection. Movie evidence: 30 FPS simulation captured offline on llvmpipe, not real-time performance validation. Candidate-only; main remains unchanged pending independent review.

## Oren map-only scale adjustment

The user selected a uniform **1.05** map render multiplier for Oren. `MAP_RENDER_FACTORS` is applied to his Sprite3D pixel size for every direction and idle/walk pose; the root/offset remain anchored at source (48,120). His destination ghost copies the selected figure's pixel size, and the fixed-scene contact shadow footprint uses the same factor. Existing HP projection follows the enlarged figure and retains its conservative width bound. Other units, portraits and battle cut-ins are unchanged.

This multiplier is deliberately separate from `character_scale`, which the existing movement speed uses. Fixed-background travel remains 0.8 seconds/grid; original 3D remains 1 second/grid, and N/L/N/R remains one cycle/grid. There is no per-frame scaling. At 1280×800 fixed view, Oren's alpha>=128 projected neutral bounds change from about 62.73×89.09 to 65.86×93.55 px, with exactly the same foot screen coordinate. Mara and Finn are unchanged. Existing pose-dependent foot silhouette variation and tiny ground-edge clipping limits remain.

`tests/test_oren_map_scale.gd` checks the four directions/poses, foot roots, HP projection, destination ghost and switching back to another unit, mode changes, 1280×800/960×600, travel/cadence and unchanged snapshot. The final 321-check test also passed with the actual Linux llvmpipe renderer. Before/after review images are delivered through Library only.
