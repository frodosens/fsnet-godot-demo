# Hybrid map magic runtime checkpoint

Base `ff248069d435953e099e29f852fa9682b5707817`; isolated branch
`work/map-magic-particles`. No main merge; generic-unit candidate not integrated.
Future integration must retain one route per event: existing map magic, supported
physical cut-in, then unsupported physical fallback. No double result projection.

## Real engine nodes

- `view/map_spell_core.gd`: nine pooled AnimatedSprite2D nodes, backed by real
  SpriteFrames. AnimationPlayer drives their phase/frame indices; sprites never
  call play(), so there is no independent frame clock or autoplay. Projected
  screen-right flight cores rotate to the target; healing stays upright.
- `view/map_magic.gd`: one manually advanced AnimationPlayer with four value
  tracks: presentation time, core phase, frame progress, travel progress. No
  method track or animation signal calls the reducer. Existing owner applies
  only queued presentation HP once when 0.62 seconds is crossed, then finishes
  at 1.35 seconds. Forward seek alone cannot apply a result. There is no user
  scrubbing UI; backward scrubbing/reversal is not an exposed feature.
- `view/map_spell_particles.gd`: 17 pooled CPUParticles2D nodes (one cast plus
  eight trail/burst pairs). 16 cast particles + 8 × (16 trail + 24 burst) =
  **336 maximum configured particle capacity**, lifetimes <=0.55s, 30Hz fixed
  particle simulation. Normal three-target ember uses seven emitters with
  capacity 136. These are bounds, not measured hardware performance guarantees.
- `view/map_particle_tint.gdshader`: additive CanvasItem shader reuses the alpha
  silhouette of the existing spark texture and lets engine particle color ramps
  provide orange fire sparks, blue energy trails, and green/gold ascending heal
  motes. No new texture art has been generated in this runtime checkpoint.

Particle motion is calculated by Godot, not by _draw loops. The emitter points
follow the map path in a projected plane; existing particles follow camera pan
and orthographic scaling. Eight decorative target slots bound cost; all Lua
recipients still receive exact HP results, numbers and runes. Offscreen emitters
are culled. Reduced motion disables all particles and core travel/frame cycling,
while preserving static cues, results and input timing. Fixed visual seeds never
read or advance shared Lua or global script RNG.

Cancellation hides/restarts/stops every emitter and disables its internal
processing. Core nodes stop and reset position, rotation, scale and frame. Scene
exit frees the pool. SceneTree pause stops both timeline updates and particle
processing. Ordinary same-step network VM replacement preserves current effects;
reconnect gaps clear effects and settle truth. The visible bottom dock HP fix is
retained.

## Core-art status: compatibility only until new atlases arrive

Existing art inventory: gather, charge, bolt, impact, dissipate are five individual
state stamps, not complete phase animations. They currently provide explicitly
reported **2 cast / 1 travel / 2 impact** compatibility frames per style.
`authored_sheet=false` is returned by diagnostics. This is not final core art.

The producer contract is [MAP_SPELL_ASSET_CONTRACT.md](MAP_SPELL_ASSET_CONTRACT.md).
Three 384×384 transparent, 4×4 atlases are required, each with 4 genuinely distinct
cast, 4 travel, and 8 impact/decay frames. Arrival of those files enables the real
4/4/8 SpriteFrames path without replacing the runtime architecture. Final hybrid
video and visual acceptance remain pending those atlases and independent review.

## Checkpoint verification (Linux Godot 4.6.3)

- Map magic: 64 checks; real Lua HP, death, queue, skip, reduced motion, reconnect.
- Engine particles: 31 checks; actual CPUParticles2D classes, emitting/internal
  processing, bounds, pool reuse, overload, offscreen cull, reduced motion, gap,
  scene destruction and deterministic snapshot preservation.
- Core/timeline: 34 checks; real node/resource classes, frame counts, phase/frame
  movement, no autoplay/second clock, pause, forward seek, single impact, cleanup.
- Bottom dock: 54; event sequence: 513; attack feedback: 66, all passed.
- Real server + two separate scene clients: focus_bolt reaches both timelines,
  polling replaces VMs, driver reconnects mid-flight, exactly one impact each,
  identical final hash `da60d7fe33efc59715d9c7d0ffb94199e50675e90906b0d69802442d7b500093`.
  The network test compares the exact saved animation age, avoiding comparison
  against an unrelated literal after AnimationPlayer interpolation.
- Actual OpenGL/Mesa llvmpipe captures verified the shader/engine particles. Local
  `/tmp/map-hybrid-*.png` are private checkpoint samples with fallback core art,
  outside Git. No Android/device/GPU performance acceptance is claimed.

Renderer rationale: project desktop and mobile use GL Compatibility. A small CPU
pool avoids requiring a renderer change or advanced GPU-only particle features.
Official references: [CPUParticles2D](https://docs.godotengine.org/en/4.6/classes/class_cpuparticles2d.html),
[renderer overview](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html).
