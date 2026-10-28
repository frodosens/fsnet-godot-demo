# Adela two-panel movement trial

Pause → 音效与动态效果 → 阿黛拉双面板移动（试验）. Independent local
setting, **off by default**. Neri's approved default remains on. Adela's idle
option remains independent and all existing static/three-pose fallbacks remain.
This adds no roster, chapter, rule, movement-speed or battle-animation changes.
Adela is a reserve visual profile: verification uses an explicit legal test roster.

The 16 PNGs are byte-identical to accepted art commit
`ba24c9cdded629ec583db8983525263265bfb30f`, under
`assets/sprites/iso4/adela_video_two_panel_walk`. The rejected four-panel candidate
is not used. Front-left and back-left each have eight original frames; right
facings reuse the corresponding left textures with `flip_h`. All are 128×128,
root (64,120); no extra pixel shift, body warp, scale compensation or disabled
depth testing. Source frames 39,42,45,48,51,55,58,61 (endpoint64) have weights
3,3,3,3,4,3,3,3, totaling25. Travel distance selects one cycle per grid regardless
of simulation speed; ordinary synchronization does not restart phase.

The runtime manifest uses canonical reserve map textures as neutral guards.
Malformed/missing configurations fail closed to old motion. Mirror resets at
turns, stop, skip, idle and ghost previews. The option refreshes only Adela.

Known visual limits: foot overlap, minor contour/detail changes and held-frame
sliding remain. Mirroring reverses weapon/costume asymmetry, while the existing
idle is unchanged; stopping can visibly change handedness and pose. Lowest
opaque rows reach y121 in some frames and retain the established ground-depth
limitation. This is an opt-in trial, not a natural-gait or seamless-transition claim.

Tests: `test_adela_motion.gd` checks weighted phases, both view modes/two
resolutions, guard/malformed fallback, roots, speed0, toggle mid-motion, skip and
ghost reset. `test_adela_motion_edges.gd` checks legal corner turns, restored
state, unrelated options, and real touch access through bounded settings scroll.
`AMBER_ADELA_MOTION=1 AMBER_WALK_ACTOR=adela AMBER_WALK_DIRECTION=<direction>
python3 tests/run_walk_network.py` runs actual authority/client synchronization.
`record_adela_motion.gd` records real Lua-authorized paths, a corner, old motion
comparison and idle transitions at normal simulation speed. Godot fixed-FPS
movie recording can render slower than wall time; it is not a device FPS test.
Media and logs stay outside Git. Only Linux was exercised; no Android claim.
