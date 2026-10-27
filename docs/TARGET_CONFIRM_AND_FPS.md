# Target confirmation and FPS

Based on main796e4c84daba4f0e1941f04541379e68ef51f54a. Presentation/input only; shared rules, native code, content and existing art unchanged.

- First click/tap selects a legal destination or action target and previews it. Another click/tap on that same target confirms. There is no double-click timeout.
- A different target replaces the proposal; an invalid target clears it. Move, attack, target-selected abilities (including self-targets), and consumables share this behavior. Wait/end-turn retain their own existing controls.
- Confirm button and Enter remain available; Cancel/right-click/Esc return to actions. Attack/ability/item confirmation uses the same dock controls as movement.
- Proposal validation includes selected actor, full action mode (including ability/item ID), target ID and cell, step, rules/content/state hashes and current Runtime identity. Pause, cancellation, selection/mode changes, new authoritative state, pending/failed sessions and presentation locks invalidate the proposal. Confirmation consumes it before submission. No rule mutation occurs during preview.
- Touch has a direct single-finger board path; Godot touch-to-mouse emulation continues to serve GUI buttons. Emulated mouse events are ignored by the board to avoid confirming the same touch twice. Other fingers do not commit commands.

FPS is always shown in the small top-right margin, on menu and in-game. It reads Godot's `Engine.get_frames_per_second()` every0.5s; this is engine-reported frame rate, not GPU duration, network rate or a diagnosis of stutter. One persistent Label ignores mouse/touch input. There is no telemetry upload, scene optimization or dynamic UI rebuilding.

Validation: complete Linux test runner5430 checks and five real network scenarios passed; subsequently expanded target test42 checks passed with real graphical viewport input, including slow confirmation, rapid repeat, target changes, invalid cells, keyboard/buttons, item consumption, actor/mode/state replacement, pending gate, injected touch and emulated-mouse deduplication. FPS bounds checked at1280x800,960x600,1200x900. Pending is an isolated gate fixture; real networking is covered separately by the existing three-process tests. Existing player-loop test now explicitly confirms target proposals and still reaches natural victory/defeat. No Windows or physical touchscreen execution claimed.

Demo uses the default New Game entry and actual UI clicks for movement preview/cancel/reselection/second-click commit, then a self-targeted skill. Real-time display capture, no fixed-fps movie mode or presentation fast-forward. Recording overhead affects the displayed FPS; it is not a performance benchmark. Media stays outside Git.
