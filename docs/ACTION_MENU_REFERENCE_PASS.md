# Move/action menu: bounded reference pass

Baseline: e6b1c1e3ba76872e9ab20ae1216307b0774fcebf. Target is the approved HUD v3 reference in `docs/art-reference/hud-v3`, not a new UI design. Linux x86_64 / Godot 4.6.3 / OpenGL Compatibility / Mesa llvmpipe. Windows candidate remains separate and unverified.

## Three changes, supported by before/after pixels

1. **Selected hierarchy.** Existing selected diamond art now grows from 64 to 76 logical pixels plus a bounded 1.02 scale (about 78 at 1280); previously it was about 67. Warm rim emphasis and a persistent left pointer distinguish selected from ordinary options. Existing 120ms selection transition remains cancellable; disabled clears it. Selection has a quiet fading row backing.
2. **Icon / key / label separation.** Reuse the existing original icon alpha silhouettes, rendered with two warm tones instead of noisy multicolor shading. Originals are untouched. Key numbers are native Labels in separate keycaps; option names remain real Button text. Wider separation replaces spaces embedded in one string. At 960×600 the option font rises from 15 to 16.5 physical pixels; at 1280×800 it stays 20. Font compensation is bounded to avoid transient/headless window sizes producing oversized controls.
3. **Local background readability.** A transparent radial quiet area sits behind the right-side menu, ignores mouse input, and hides with the menu. No world-light, background-image, character, status-panel or path shader adjustment. Pixel comparison outside the right-side region changed only 12 pixels at 1280 and 3 at 960 (capture timing); there is no global darkening.

## Images / recording

- [Reference / before / after comparison](action-menu-reference-comparison.png)
- [1280 before](action-menu-before-1280.jpg) / [1280 after](action-menu-after-1280.jpg)
- [960 before](action-menu-before-960.jpg) / [960 after](action-menu-after-960.jpg)
- [Actual selection, mouse input, path and spent-option recording](runtime-video/action-menu-reference-pass.mp4): 318 frames / 30fps, 10.6s. Offline capture, not a hardware FPS benchmark.

Comparison uses a **uniform** reference scale of 1280/reference width; actual runtime crops remain unretouched. The concept's wider aspect ratio means vertical spacing differs; it was not stretched to manufacture a match. Normalized row centers remain x=.88, y=.31/.41/.50/.59, preserving the approved placement contract. Selected frame, pointer and text are independent of the background image.

## Input and regression verification

`tests/test_action_menu_art.gd`: 35 checks, including both sizes, font bounds, native key labels, pointer-safe quiet area, keyboard focus, Enter activation exactly once, synthetic controller D-pad/accept, fast selection replacement, disabled clearing and unchanged rule snapshot. Also executed under the actual graphical renderer. Physical controller hardware was not tested, and this does not add full controller board targeting.

Enter previously reached the gameplay shortcut that reopened the menu and reset focus to Move instead of activating the focused Skill. The unhandled-input fallback now activates a visible enabled focused action first; ordinary GUI handling retains priority, preventing duplicate invocation.

Final complete suite: 1,585 checks, no errors, four real fsnet server/two-client/reconnect scenarios passed. The UI-driven victory/save/load/defeat loop still passes. Static facing-idle locomotion and shared Lua/game content are unchanged.

## Remaining fidelity limits — stop condition

This is closer, not pixel-perfect. Existing boot/pouch silhouettes and metallic border texture remain more detailed than the reference. The two-tone shader cannot recreate different source drawing. A future art-only refinement would replace the four transparent 64×64 action glyphs (boot/sword/sparkles/pouch, centered, simple cream/tan masses with one broad shadow) and optionally the 96×96 selected border (thin cream inner line, restrained gold outer line), preserving the same pivots and interfaces. No such new assets were generated in this pass.

Scene illustration, lighting, left status art, combat and other systems are intentionally outside this bounded menu pass. No Windows CI/API retry was made. This pass ends after the above evidence and checks.
