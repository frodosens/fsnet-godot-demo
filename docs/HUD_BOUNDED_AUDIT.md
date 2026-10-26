# Bounded HUD audit after 0226809

Actual Godot 4.6.3 / Mesa llvmpipe window: 960×600 pixels. Canvas-items logical coordinates: 1280×800. This is a real render, not an offline resized screenshot. `docs/reference-hud-960x600.png` captures the same reference map, selected Mara and a real three-step BFS preview.

`test_hud_reference_layout.gd`: 13 checks passed in the graphical process. Four command anchors have zero measured logical-pixel error; companion centers differ by at most 0.2 logical pixels. Checks include repeated selection settling, preview keeping the command group visible, and disabling clearing the animation. This is not a new six-resolution matrix.

Visual findings:
- Selected portrait, two companion portraits, Chinese identity text, HP/MP values, and action counts remain inside the window, without overlap. No blocker found requiring further layout code in this audit.
- Property icons are 20 logical px = 15 physical px at this window size. The heart/crystal are recognizable, while the boot/action glyph details become busy. Main action icons are 28 logical px = 21 physical px and have Chinese labels; do not claim all icons are self-explanatory without labels. Better simplified silhouettes should be an art refinement, not another decorative frame.
- The captured route uses [(4,7),(4,6),(4,5),(4,4)], matching rules and animation. It is not traced from the concept.
- Source art remains the principal gap: repeated identical trees, hard-edged canal-like bank stones, inn roof/porch silhouette and composition differ from the approved concept. Current directional lighting/shadows exist; calling the scene 'unlit' would be inaccurate. No further geometry/camera churn was performed in this bounded audit.

Pending art: additional tree species/silhouettes and knight/front_right walk contact/pass poses. For the gait artist, keep 96×128, feet anchor (48,120), current iso projection and identity. Existing 00/01 and 02/03 pairs retain near-identical supporting-leg placement; the engine now has explicit stride/fps tuning. Precise contact sockets should be attached to the revised frames if available, rather than inventing coordinates for ambiguous existing foot silhouettes. Current engine does not claim source-foot-lock verification.

Android preparation remains local and paused; no installation, license acceptance or access workaround was performed.
