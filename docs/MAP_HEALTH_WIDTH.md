# Map overhead health meters

This change is presentation-only. It does not affect the combat cut-in HP cards,
the lower-left status HUD, HP rules, snapshots, or network hashes.

The full meter backing and frame fit inside 96% of the projected opaque body
width. A cached measurement finds the largest 8-connected alpha >= 0.5 component
of each applicable directional/idle texture, excluding transparent padding and
isolated specks. The smallest width across the character's applicable directions
and idle frames is used, so breathing, facing, damage, and selection cannot widen
or jitter the bar. Texture pixels are measured once per loaded texture, not per
frame. There is no width minimum overriding a narrow character. Height retains
the existing thin frame and at least 8 physical pixels. Faction shape is centered
above the bar, within its horizontal span.

Automatic horizontal avoidance of nearby faces defaults **off**. Normal tracking
of the owner's head and camera remains active. The generated-theme checkbox
“头顶血条自动避让” in pause → “音效与动态效果” restores the optional face-avoidance
behavior. Its boolean lives in `user://presentation.cfg`, separate from game
saves; missing or malformed values default off. Other config keys are preserved.

`tests/test_health_width.gd` covers eight supported identities, four directions,
idle phases, selected/damaged meters, 1280×800 and 960×600, persisted preferences,
a deliberately crowded scene, role/texture fallback, actual movement and rule
state preservation. `tests/test_unit_health.gd` retains full/half/dead HP and
fixed-background/3D coverage. Linux Godot 4.6.3 visual checks do not establish
Windows visual compatibility.
