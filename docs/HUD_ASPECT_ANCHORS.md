# HUD safe-area edge anchors

The battle dock keeps its 1586×992 measured design and uniform fit scale. Its
canvas fits inside the HUD safe rectangle and anchors to the bottom edge; the
phase group compensates for that vertical offset to remain top anchored.
This removes the floating bottom dock on taller landscape viewports without
changing map cover, camera bounds, targeting coordinates or artwork proportions.

Skill/item pickers receive the dock's actual notice boundary instead of guessing
it from 81% of viewport height. Their existing touch ownership, outside dismissal,
scrolling descriptions and command validation remain intact. Standalone pickers
retain their default placement. General pause/settings pages are unchanged.

Focused regression:

```
godot --headless --path . --script res://tests/test_hud_aspect_anchors.gd
```

The test exercises 1280×720, 1280×800, 1024×768, 2400×1080 and 960×600,
with and without simulated physical safe-area insets. It verifies top/bottom
anchors, uniform scale, control containment, picker/description fit, raw touch
outside dismissal and direct command switching without battle mutation.
Set `HUD_CAPTURE_DIR` to an existing external directory and run with a graphical
display to capture the five actual rendered viewports. Captures are Linux
simulation, not Android hardware evidence. Do not commit captures or APKs.
