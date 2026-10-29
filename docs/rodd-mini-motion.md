> Superseded rollout policy: see [latest-map-animations.md](latest-map-animations.md). The latest user instruction enables Rodd and removes animation toggles despite the disclosed shoe clipping; the earlier OFF/rollback description below records the admission trial.

# Rodd map motion trial

Independent local `罗德地图动作（试验）` option under Pause → 音效与动态效果. Default OFF pending independent runtime/visual review. Explicit OFF persists; no other animation preference, portrait, battle pose, chapter roster or gameplay rule is changed.

Eighteen unchanged PNGs in `assets/sprites/iso4/rodd_seedance_mini_v1`: eight motion frames and one static idle for each left-facing source. Front-right/back-right mirror their matching left source in both idle and movement. Canvas160×160, root(80,144), eight weights of3, cycle24 ticks sampled by actual travel distance once per grid. Movement speed is unchanged. Original128×128 idle sprites are exactly padded by(16,24), not regenerated. The profile's neutral guard explicitly declares128×128/root(64,120); the supplied manifest omitted this and initially failed closed against the96×128 default. Only this guard metadata was corrected; a non-runtime source task identifier was omitted from the art receipt. PNG bytes remain identical to the staged art.

The renderer reuses the bounded160px map pipeline for explicit ID `rodd` only; unknown Mod IDs and mismatching neutral textures fall back. A separate preference avoids expanding or resetting the three-hero preference dictionary. No generic soldier identity substitution is involved.

Validation includes all four directions, fixed background and3D,1280×800/960×600, idle/move roots and scale, weighted phase, ghost/HP positions, turn/stop/skip, zero-speed pause, same-step refresh and rollback. The capture driver issues legal player move commands in an explicit test placement and runs normal simulation speed at a fixed30fps capture clock; it is not a hardware frame-rate measurement. Native network tests observe31 Runtime replacements per direction without restarting the eight-frame cycle. Settings tests verify the actual14 controls and their order.

Art limits: a stylized walk changes face/clothing rendering from the unchanged old idle; mirrored equipment reverses hands consistently. Toe/sole pixels extend below the logical root (source alpha bottoms144–149 front,145–149 back), so padded images alone do not prove full ground clearance. Ground-depth testing is preserved; no per-frame recentering, body shrinking, depth disabling or limb repair was added. Do not claim anatomically perfect walking or zero sliding.

Run `tests/test_rodd_motion_assets.py`, Godot `test_rodd_motion`, `test_rodd_motion_scene`, and existing `run_walk_network.py` with `AMBER_HERO_REFRESH=1 AMBER_WALK_ACTOR=rodd` and each `AMBER_WALK_DIRECTION`. Evidence media remains outside Git. Linux only; no Android/Windows execution or APK claim.
