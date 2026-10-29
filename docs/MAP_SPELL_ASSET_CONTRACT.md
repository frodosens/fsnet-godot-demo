# Hybrid map magic core art contract

Requested hybrid: actual AnimatedSprite2D/SpriteFrames core, CPUParticles2D
auxiliary sparks/motes, AnimationPlayer phase/frame/travel tracks. Shared Lua and
0.62s presentation-impact boundary remain unchanged. No gameplay method tracks.

## Required art (not present in the old five-stamp library)

Supply three transparent PNG files under `assets/effects/map_spells/`:
`ember.png`, `focus_bolt.png`, `heal.png`. Each is exactly 384×384 pixels, a
4-column × 4-row grid of 96×96 cells, row-major, no gutters/grid/text/labels.

- Cells 0–3: four genuinely distinct cast/gather frames, 0.00–0.30s.
- Cells 4–7: four distinct travel frames, 0.30–0.62s. Ember fireball and focus
  bolt face screen-right; runtime rotates this stage to the actual projected path.
  Heal uses ascending light instead of a projectile and is never rotated.
- Cells 8–15: eight distinct impact→decay frames, 0.62–1.35s, upright and centered.
- All frames share pivot (48,48); retain clear transparent margins. No characters,
  scenery, opaque background, baked shadows, screen flash, or full-screen effects.
- Ember: warm orange/gold fire silhouette, irregular flame contours; fire/sparks
  are presentation styling, not a new damage type. Focus: blue/cyan coherent
  energy bolt and impact. Heal: green/gold restorative light, upward/soft burst.
- Pixel style, readable compact silhouettes, meaningful frame-to-frame evolution;
  do not duplicate a static stamp or only scale/fade it and call it authored art.

Existing `ranged_magic/runtime/vfx_*` are only five isolated state images. Until
these sheets arrive the adapter exposes an explicit compatibility fallback of
2 cast / 1 travel / 2 impact frames, not a finished core sequence. Diagnostics
report authored_sheet=false. Final visual acceptance is blocked on real art.

No paid generation, new skills, or main merge is authorized by this contract.
Parent thread owns image generation and formal-resource backup.
