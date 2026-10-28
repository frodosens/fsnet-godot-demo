# Neri movement mirror trial

This opt-in map presentation trial is independent of Neri's existing video idle switch. Both default off. Enable “奈莉镜像移动（试验）” under Pause → sound/motion settings. Disabling it restores the existing three-pose front-right walk and static fallback in the other directions. It does not add a battle animation, change global direction mapping, or change game rules.

The 24 source PNGs are 128×128 with root (64,120). `assets/animations/neri_motion_trial.json` uses the existing weighted sequence decoder in a separate instance. Each direction retains its original canonical neutral guard. Front-right references the same eight front-left textures with `flip_h: true`; the other three directions use their own source unmirrored. No duplicate mirrored PNG, negative scale, frame recentering, one-pixel correction, or new generated art is involved. The staff hand reverses in front-right and returns to the original hand at idle; this is an acknowledged workaround, not anatomically independent art.

Weights `[4,3,4,3,4,4,3,4]` sum to 29 source ticks at 24 Hz. Movement uses these as relative phase weights over one grid of actual travel, keeping existing speed (0.8 s/grid in the reference fixed scene at scale 1.25; 1 s/grid at scale 1.0). The 29/24 s source loop is not a second animation clock. Start uses the original neutral; stopping, skipping, failed-profile fallback and ordinary idle clear the flip. Turns update the source and flip together. Same-step network refresh retains travel and pose. Target ghosts remain unmirrored idle previews.

`flip_h` must be a JSON boolean; malformed clips invalidate the whole profile. Other profiles default to false. Loading uses cached Texture2D resources, not per-frame image reads or alpha scans. Neri's independent trial does not replace the shared idle profile or Finn's newly regenerated motion. Local presentation preferences are outside save/network deterministic state.

Known limits: mirrored front-right reverses equipment hands; pose/size changes versus old idle and residual foot sliding can remain. Source opaque extent reaches exclusive bottom 121 (front) and 122 (rear), so the existing depth-tested ground can trim a low foot edge. Depth testing and world root are preserved. Successful loader/route tests do not certify anatomical gait. The available comparison uses old in-game front-right three-pose motion, not the rejected original source-video upper-right panel, which is intentionally absent from the runtime package.

Validation commands:

- `godot --headless --path . --script res://tests/test_neri_mirror.gd`
- `godot --headless --path . --script res://tests/test_neri_mirror_edges.gd`
- `python3 tests/test_neri_mirror_source.py`
- `AMBER_NERI_MIRROR=1 AMBER_COMPACT_SEQUENCE=1 AMBER_WALK_ACTOR=neri AMBER_WALK_DIRECTION=front_right python3 tests/run_walk_network.py` (repeat all four directions).
- Actual graphical tests use the same scripts without `--headless`; Linux Godot4.6.3 Compatibility/llvmpipe is the available environment, not Android/Windows device validation.

`tests/record_neri_mirror.gd` records legal test placements, an old front-right comparison and the four new directions. Set `AMBER_NERI_CAPTURE` to an existing local directory; movie capture with `--fixed-fps 60 --write-movie /tmp/trial.avi` runs normal simulation speed offline, not a real-time FPS benchmark. Review screenshots and recordings stay outside Git.
