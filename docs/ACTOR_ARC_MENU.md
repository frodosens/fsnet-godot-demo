# Actor-anchored action arc

The user's latest layout supersedes the earlier fixed right-edge HUD reference. The four real action buttons now surround the selected actor in an arc. Right is the preferred candidate; crowded layouts and viewport edges can select left, above or below. Labels, icons, keyboard focus and enabled states remain interactive controls.

Selection moves the chosen item **14 logical pixels left over 140 ms**, with its existing highlighted art and small scale response. Previous items return, obsolete tweens are killed, and hiding/reselecting clears animation state. Left motion remains left even when the entire arc changes sides. Disabled text stays readable and cannot activate. Existing icon art uses a smooth contrast material rather than a binary silhouette threshold.

The layout uses the camera projection every refresh, selected sprite/HP keep-out, other live actors and HUD reserved areas. Whole-arc safe-area adjustment preserves the curved arrangement. It is a finite candidate solver, not a guarantee that arbitrarily crowded custom maps can avoid every other actor and HUD element; the selected actor and viewport were verified in the documented edge fixtures.

## Interaction

Select a hero → choose Move → arc hides and the authoritative reachable area appears → hover previews the existing Lua BFS path → one destination click executes it. Right click/Esc cancels without a command and restores the arc. Completion restores options with spent actions disabled. Skill/item Back restores the arc. No rule, RNG, network, static directional-idle movement, lighting or combat changes.

An early regression let the relocated menu cover another hero's board click. Live-actor exclusion rectangles fixed it; the complete UI battle loop passes again. A second regression left the arc closed after backing out of a skill/item dialog; closing the modal now restores it.

## Validation

Linux, Godot 4.6.3, OpenGL Compatibility, Mesa llvmpipe. `tools/test.sh`: **1714 checks**, plus four three-process server/two-client consistency/reconnect runs. The suite includes real viewport button/cell events for new game, story, skill, item, AI turns, victory (step 20), defeat (step 12), save/load. Presentation is explicitly fast-forwarded in that full-loop test.

`tests/test_actor_arc.gd`: 128 checks, including 15 synthetic edge-layout cases across 1280×800, 960×600 and 1920×1080, left translation, projection tracking, reselection, cancel invariance and actual destination click. `test_action_menu_art.gd` also passed **35 checks in the graphical renderer**, including keyboard Enter and synthetic controller D-pad/A input. No physical controller was connected.

`capture_actor_arc.gd` captures actual 1280×800 and 960×600 viewports. Separate original-3D camera fixtures project the selected actor to (1190,390), (90,150), (650,680) and verify actor/HP exclusion. These are camera framing tests, not changed map rules or fixed-background coordinates.

`record_actor_arc.gd` records real mouse hover/click selection, hiding for target preview, a one-click three-cell move (exactly one command), menu restoration, then original-3D edge fixtures. Movie-mode video is visual evidence, not a real-time performance benchmark. Frame inspection confirms distinct selection positions, menu hidden during travel, static facing sprites and restored options.

Artifacts:
- `actor-arc-1280.png`, `actor-arc-960.png`: actual fixed-background scene.
- `actor-arc-right-edge.png`: original-3D edge fixture.
- `runtime-video/actor-arc-menu.mp4`: selection and movement, followed by edge fixtures.
- `validation/actor-arc-suite.txt`, `validation/actor-arc-graphical-input.txt`.

This is intentionally no longer a pixel-for-pixel match to the old fixed-right concept. Existing detailed icons and local shaded backing remain; no new art was generated. Windows runtime/build candidate remains separate and unverified. No denied Actions API request was retried.
