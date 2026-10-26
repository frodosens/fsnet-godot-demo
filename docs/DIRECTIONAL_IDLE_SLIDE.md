# Directional idle slide (current map locomotion)

User chose to stop both IK and walking animation. All six map roles now use their existing direction-specific static idle texture while translating along the authoritative Lua path. Facing updates at each path segment and persists at rest. No gait loading, frame cycling, SubViewport rig, bounce, squash or extra locomotion effect. Combat cut-ins are unchanged. Original art and historical experimental source are retained, not active.

`view/unit_motion.gd`: presentation speed = 1 world unit/s × existing character scale × speed multiplier. This parameter no longer pretends to be a gait cadence. Large timesteps cross all segments; replay duplicate step does not restart; skip/cancel settles to rule state. UI preview cancellation still sends no command. Movement after confirmation cannot undo an authoritative command.

## Validation

- `tests/test_idle_slide.gd`: 102 checks, six real roles × four projected directions, repeated static texture, duplicate event, skip, real Lua corner path, completion and replay; snapshot/RNG unchanged. All-direction coverage uses explicitly synthetic presentation events; real movement path coverage uses the actual command pipeline.
- Complete active suite: 1,489 checks, zero failures; four real fsnet server/two-client/reconnect runs passed. Includes menus, story/save/load, abilities/items/AI/objectives, damage/cut-ins, paths and lighting state. Tests are not a claim of full manual playthrough on every platform.
- Real Godot 4.6.3 / Linux x86_64 / Mesa llvmpipe capture: [6.73s map video](runtime-video/directional-idle-slide.mp4), [screenshot](directional-idle-slide.jpg). Actual mouse hover/one-click path recording, fixed background, lamps/shadows/thin HP preserved. 202 frames at fixed 30fps; offline capture rate is not a runtime performance claim.
- Old `test_motion.gd`, `test_gait_distance.gd` and `test_sprite_frame_route.gd` exercise superseded walk-frame assumptions and are retained as historical diagnostics, excluded from the active suite.

Limit: characters visibly slide in one static pose per direction by design. This is not a natural walking animation and is not described as solving historical gait art quality. No new character art or IK tuning is included.
