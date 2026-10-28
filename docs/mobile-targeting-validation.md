# Mobile targeting and battle presentation candidate

The existing bottom action dock remains unchanged. A first valid map tap previews;
a second tap on the same target submits through the existing validated command
queue. Confirm and Cancel remain available. Skill/item modal dismissal now hides
and queues the panel for deletion instead of removing a pressed control during
raw-touch/emulated-mouse event dispatch.

Targeting overlays share the world-ground mesh and camera transform:

- Blue is a Manhattan cast-distance reference, not a promise of line of sight.
- Gold borders mark actual legal unit targets, queried from Lua preview authority.
- Orange marks the selected/hovered legal target's effect radius, distinct from
  cast distance. Effects apply only to the primary target's faction per Lua rules.
- Red marks an invalid hovered/tapped cell. Resource/faction/distance feedback is
  shown in the existing preview context. Costs and effect radius remain visible.

Overlay queries are cached by actor/mode/runtime/step/hover/selection/input lock.
No rules, RNG, save format, or network protocol changes are introduced.

On mobile, battle scenery, actors and effects share a uniform cover transform.
The battle status UI keeps a separate uniform design fit within the safe area.
Desktop scene fit is retained. Background textures preserve their aspect ratio.

Focused tests (Godot 4.6.3, existing host GDExtension):

```
godot --headless --path . --script res://tests/test_mobile_targeting.gd
godot --headless --path . --script res://tests/test_mobile_cutin_layout.gd
```

Raw-touch tests enable mouse emulation, use actual menu buttons, and cover attack,
self skill and item second-tap commits at 2400x1080 and 1280x800, pan projection,
AoE/faction visibility, skill switching, cancellation, resource denial and pending
network input. Existing mobile camera, target confirmation, Wait, combat sides,
contact and chapter/checkpoint tests remain relevant.

Baseline and candidate were actually rendered with Linux Xorg dummy + Mesa
llvmpipe at both resolutions using a legal adjacent-unit content fixture. This
is simulated desktop input/rendering, not Android hardware validation or a
performance benchmark. Screenshots and toolchains stay outside Git. No APK is
published by this candidate; combined Android delivery requires coordination.
