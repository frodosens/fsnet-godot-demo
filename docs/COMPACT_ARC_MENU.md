# Compact action plates and selection scale

Supersedes the broad menu backing in ACTOR_ARC_MENU.md / commit 68b503c. The old radial TextureRect darkened units even when button rectangles avoided them. It has been removed completely.

Each option now has a small translucent dark-teal/warm-gray cut-corner plate underneath its key and text, a thin bronze rim and a restrained upper highlight. The existing diamond icon art remains separate. Space between options and around characters is transparent. Plates render behind native Button text (the first candidate revealed an incorrect paint order in real screenshots; corrected before publication). No full-menu gradient, screen filter or new source artwork.

Selected scale is exactly **1.00**; inactive/disabled scale is **0.85**. Entire compositions scale together around the icon center and translate 14px left over 140ms on selection. Changing selection kills the previous tween and continues from its current transform. Reduced-motion uses immediate final transforms. The old selected frame enlargement was removed. Minimum-window text compensates for inactive scaling; 76px-high controls retain approximately 48 physical pixels of click height at 960×600.

The solver's conservative painted envelope is local (-44,-12) through (182,78), including the icon rim, pointer, plate edge, normal maximum scale, font outline and selected-left travel. No paint is added outside that envelope. Actor/HP and other-actor reservations are preserved.

Validation: Linux Godot 4.6.3 / OpenGL Compatibility / Mesa llvmpipe. Full suite **1716 checks + four three-process network/reconnect runs passed**. Includes whole playable UI victory/defeat/save/load loop, arc cancel/restore, normal/inactive scales and reduced-motion assertions. Graphical keyboard/mouse/synthetic controller suite: 35 checks passed. Physical controller/Windows not tested.

Actual 1280×800 and 960×600 captures and original-3D right-edge fixture were visually inspected against their previous captures: Finn and the space between characters are no longer covered by the broad dark backing; text remains readable on bright ground. The 13-second movie uses actual mouse events, selection changes, single-click movement and edge fixtures. It is not a performance benchmark.

Artifacts: compact-arc-1280.png, compact-arc-960.png, compact-arc-right-edge.png; runtime-video/compact-arc-menu.mp4; validation/compact-arc-suite.txt and compact-arc-input.txt. Prior captures remain for comparison.

Finite-candidate layout cannot promise zero occlusion on arbitrarily crowded custom maps. This change is confined to menu appearance/bounds; no rule, map, locomotion, lighting or network changes.
