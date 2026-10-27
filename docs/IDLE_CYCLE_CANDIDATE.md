# Four-direction map and side-view battle idle: candidate interface

Status: **interface candidate only**. No accepted new idle artwork is supplied and no
multi-frame idle is enabled by default. Existing single-frame and attack/hit assets
remain unchanged. No eight-direction battle requirement. This branch is not main.

Optional local runtime manifest: `assets/animations/idle_cycles.json`:

```json
{"version":1,"map":{"knight:back_right":{"frames":["assets/path/frame00.png","assets/path/frame01.png"],"frame_ms":[160,160]}},"battle":{"mara:right":{"frames":["assets/path/frame00.png","assets/path/frame01.png"],"frame_ms":[160,160]}}}
```

The example paths are placeholders, not assets to load. Map keys are role + one of
front_left/front_right/back_left/back_right; battle keys are character ID + right,
with `oren:left` separately supported for his existing left-facing defender.
Other defenders use the right-facing cycle with the existing horizontal flip.
Do not reuse map art in the battle collection.

Map canvas is 96x128, foot pivot (48,120); battle canvas 192x160, pivot (96,144).
Every frame must retain the same registration and fixed support baseline. No
per-frame bbox normalization, global bobbing, position offset, or scaling is applied.
Frames must be asset PNGs of the expected dimensions, 1–32 per clip, durations
40–2000 ms each. Missing/invalid clips fall back atomically to existing art; loader
errors are available in `IdleLibrary.errors`. Missing manifest is normal legacy mode.

Map clocks reset on facing changes, motion and death, freeze while a modal/story or
cut-in is open, and are destroyed with the scene. Motion remains the existing
static directional slide until separately accepted walk assets/player are available.
Reduced-motion samples frame zero. No clocks enter saves, commands or shared hashes.

Battle idle only replaces the first two and final two authored ticks of the attacker,
and the defender's pre-brace idle / post-recovery idle. Existing attack, brace, hit,
recovery, contact, HP timing, speed, hitstop and skip remain authoritative for this
presentation. Post-recovery idle restarts at frame zero. Clips therefore do not yet
get a long stage idle interval: a complete idle loop may not be visible in a short
cut-in. Extending the stage hold is a later art/timing acceptance decision, not a
silent change here. Dead defenders never return to idle. Tree pause freezes normal
processing; skip closes the surface and a new event begins at time zero.

Validation: `tests/test_idle_cycles.gd` uses existing distinct poses only as sentinel
textures to verify time selection, fallback/validation, pause/move/direction reset,
foot-position invariance, cut-in hit preservation, skip and scene destruction.
These test sentinels are **not proposed idle artwork**. Actual loop quality, foot
registration, light consistency and all six roles require the upcoming artwork and
real rendered acceptance before integration into main.
