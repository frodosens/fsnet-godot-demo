# V2 runtime integration

The approved art/ui-v2 assets were cherry-picked from2e66d1f. Main menu uses the real authored background with native Chinese title and four plain text buttons; a small native amber diamond and quiet focus fill retain keyboard/mouse interaction. The workshop is a secondary link. No screenshot is used as a fake clickable menu.

Authored panel/button textures skin dialogue, HUD, pause/save/lobby/editor and inventory. Chinese text remains native and readable. The scene palette and global lighting were reduced in saturation to avoid washing out the directional sprite colors. This is not a claim that the simple geometric map has received final authored environment art, or that existing portraits are all final V2 character art.

`tests/capture_scenes.gd` regenerated menu-runtime.png,portrait-dialogue-runtime.png,battle-ui-runtime.png,sword-cutin-runtime.png on actual X11/Mesa llvmpipe. The sword screenshot remains a clearly identified adjacent-unit legal-attack fixture, stopped at presentation tick11. Other screenshots are the real new-game flow. Full UI/core/network regression passes; raw evidence in validation/ui-v2-runtime.txt.

Movement now emits a deterministic BFS path as a presentation event. `view/unit_motion.gd` reads a fixed walk manifest, cycles frames along path segments, keeps idle facing, supports skip and interrupts safely on a newer authoritative step. It never submits commands or alters the rules state. With no real walk assets present it does not claim or simulate a finished walk cycle. Eight lifecycle/timing checks use explicit coloured1px test doubles only; no screenshot/video of those substitutes is presented as animation art.

Current motion input: assets/sprites/walk/manifest.json with fps8 and characters[role][front|back|left|right] arrays of four or more res-relative paths beneath assets/sprites/walk/. Per-direction {frames:[...]} is also accepted. No mirrored direction generation. Real walk assets and all-role battle animation remain acceptance work in progress.
