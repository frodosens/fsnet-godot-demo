# Tessa prompt-video movement trial

This opt-in trial uses the 32 unchanged PNGs from art commit
`7dad7f638c2f5967595657d78d9abd24aadb3072`. Source provenance, original video
hash, keying, fixed registration and per-frame hashes are recorded in
`assets/sprites/iso4/tessa_video_compact/source_manifest.json`.
The integration executor inspected these PNGs; its original Library video
transfer failed, so it does not claim independent inspection of the raw video.

Enable Pause → 音效与动态效果 → 泰莎视频移动（试验）. It defaults off and
only changes Tessa movement. Old idle, existing walking fallback, other actors,
Oren's 1.05 render factor, combat and authoritative rules remain unchanged.

Four facings each contain eight frames, source indices 48,51,54,57,60,63,66,69;
cycle end is 72 at 24 Hz. Eight weights of three map to one actual traveled grid,
not a new timer or movement-speed change. The shared loader admits 128×136 only
for Tessa's motion profile; other profiles keep their previous canvas contracts.
Malformed profiles retain the old movement fallback.

The canvas retains root (64,120) and body pixel scale. Tessa's Sprite3D offset is
52 while displaying 136-high frames, and returns to 56 for the original 128-high
idle/walk art. Ghost placement follows the same root. No image mutation, per-frame
alignment, body warp, IK, actor lift or depth override is used.

## Known visual limitation

Bottom padding prevents PNG truncation, but it does not fix ground intersection.
The camera-facing character plane puts pixels below root y=120 below the physical
3D ground. Frontward extended feet reach roughly y=132 and can visibly lose their
lower rows in the 3D view. The fixed-background view has no physical ground at that
location and displays the extended shoe. This trial is not a claim of perfect
foot locking, zero sliding, seamless idle pose transitions, or final art acceptance.
The switch remains reversible; main integration requires independent review.

## Validation and reproduction

- `tests/test_tessa_sequence.gd`: weighted duration, malformed mode/cycle fallback,
  unit-scoped binding, independent persistent option.
- `tests/test_tessa_sequence_scene.gd`: all directions in both render modes,
  actual legal commands, distance phase, unchanged scale/root, HP, pause,
  toggle during movement, stop/skip and return to old idle.
- `tests/test_tessa_sequence_edges.gd`: actual settings mouse/keyboard at 1280×800
  and 960×600, ghost, legal corner, duplicate event, large delta, save/load.
- `AMBER_COMPACT_SEQUENCE=1 AMBER_WALK_ACTOR=tessa AMBER_WALK_DIRECTION=<direction>
  python3 tests/run_walk_network.py`: actual authority/client synchronization.
- `tests/record_tessa_sequence.gd`: four directional routes and a bent path from
  explicitly labeled legal test placements, using original shared movement commands.
  Set `AMBER_COMPACT_CAPTURE` to a local directory; optional `AMBER_COMPACT_3D=1`.
  Movie Maker uses fixed-step offline capture, normal simulation speed; it is not
  a real-time FPS benchmark. Do not commit generated media.

Linux Godot 4.6.3 only. Targeted checks: config 138, scene 6464, graphical edges 82;
all four real-network directions observed 31 Runtime replacements with no restart.
Existing Finn, sequence, idle options, character projection, Oren scale, route and
confirmation regressions also passed. No full-suite or Windows execution claim.
