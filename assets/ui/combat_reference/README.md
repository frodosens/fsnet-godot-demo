# Combat reference runtime assets

Approved same-style combat UI and a map-derived battle background. This branch adds assets only; it does not modify game code or implement combat mechanics.

## Contents
- 16 independent RGBA UI PNGs in this folder: paired status frames, move-title frame, HP track and ally/enemy/recent-loss fills, speed/skip normal/focused/pressed buttons, and three independent icons.
- `res://assets/backgrounds/amber_bridge_battle/background.png`: native 1586×992 RGB background, with no actors or interface baked in.
- `manifest.json`: dimensions, SHA256, original layout rectangles, nine-patch margins, provenance and integration constraints.

## Integration contract
Use the 1586×992 design canvas with uniform scaling. Left/right status cards occupy `[18,756,622,156]` and `[944,756,622,156]`; the title occupies `[540,58,506,80]`. Speed and skip remain small lower-edge controls. Match the recorded copper/ivory trim, textured bluegray materials and original hierarchy; do not redesign the approved layout.

Actor feet belong around y=635–650, within the clear battle-floor band. HUD begins at y=756. Do not place actors at the old draft floorline y=694, which includes foreground grass. Portraits, names, HP numbers, title, labels, actors and effects remain separate runtime layers. HP sample values from previews are not gameplay statistics.

Use the listed nine-patch margins for resizable frames. HP fills are full-width textures and should be clipped to live HP fraction, not compressed. The recent-loss fill can be shown at 0.35 opacity. The title is informational, not an added skill-selection mechanic. Audio/accessibility controls stay in settings.

## Provenance and validation
Generated with built-in OpenAI imagegen from the approved map/combat visual direction. UI components were generated independently, then cropped, alpha-cleaned and three-slice normalized; they are not production crops of a flattened concept. The background is unchanged at native resolution. Static pixel/PNG dimensions, transparent corners and local hashes were checked. Godot import and runtime visual/interaction tests remain the responsibility of the integration change.

Only runtime textures and this concise contract are included. No concept sheets, combined previews, screenshots, videos, generator source sheets, local/private paths or Library links are published.
