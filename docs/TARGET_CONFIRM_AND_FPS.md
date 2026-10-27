# Target confirmation and FPS

Based on main796e4c84daba4f0e1941f04541379e68ef51f54a. Presentation/input only; shared rules, native code, content and existing art unchanged.

- First click/tap selects a legal destination or action target and previews it. Another click/tap on that same target confirms. There is no double-click timeout.
- A different target replaces the proposal; an invalid target clears it. Move, attack, target-selected abilities (including self-targets), and consumables share this behavior. Wait/end-turn retain their own existing controls.
- Confirm button and Enter remain available; Cancel/right-click/Esc return to actions. Attack/ability/item confirmation uses the same dock controls as movement.
- Proposal validation includes selected actor, full action mode (including ability/item ID), target ID and cell, step, rules/content/state hashes and Session identity / connection generation. Pause, cancellation, selection/mode changes, new authoritative state, pending actions/failed sessions and presentation locks invalidate the proposal. Confirmation consumes it before submission. No rule mutation occurs during preview.
- Touch has a direct single-finger board path; Godot touch-to-mouse emulation continues to serve GUI buttons. Emulated mouse events are ignored by the board to avoid confirming the same touch twice. Other fingers do not commit commands.

FPS is always shown in the small top-right margin, on menu and in-game. It reads Godot's `Engine.get_frames_per_second()` every0.5s; this is engine-reported frame rate, not GPU duration, network rate or a diagnosis of stutter. One persistent Label ignores mouse/touch input. There is no telemetry upload, scene optimization or dynamic UI rebuilding.

Validation: complete Linux test runner5430 checks and five real network scenarios passed; subsequently expanded target test42 checks passed with real graphical viewport input, including slow confirmation, rapid repeat, target changes, invalid cells, keyboard/buttons, item consumption, actor/mode/state replacement, pending gate, injected touch and emulated-mouse deduplication. FPS bounds checked at1280x800,960x600,1200x900. The ordinary poll/command distinction is covered by the three-process target-confirmation regression described below. Existing player-loop test now explicitly confirms target proposals and still reaches natural victory/defeat. No Windows or physical touchscreen execution claimed.

Demo uses the default New Game entry and actual UI clicks for movement preview/cancel/reselection/second-click commit, then a self-targeted skill. Real-time display capture, no fixed-fps movie mode or presentation fast-forward. Recording overhead affects the displayed FPS; it is not a performance benchmark. Media stays outside Git.


## Ordinary polling and deferred confirmation

Session `pending` describes the occupied transport slot, not necessarily a command. `command_pending` describes an actual submitted action; `ready` and `connection_generation` distinguish a healthy synchronized connection from startup/reconnect. A validated ordinary sync can replace Runtime without changing the state, so Runtime identity alone never invalidates a target. Changed step/content/rules/snapshot, actor/action or session/connection identity still invalidate it.

If confirmation arrives during an ordinary poll, the view stores one confirmed proposal and reserves the next free transport slot (`defer_poll`). The poll reply is validated first. Only an unchanged, still-valid proposal is sent, once; cancellation/pause, real state changes, disconnects or scene exit release the reservation. Poll delay cannot starve confirmation by immediately launching another poll. No blind command retransmission or overlapping requests is introduced.

`tests/run_target_network.py` runs a real fsnet server, remote player, and viewport-driven client in three OS processes. Set `AMBER_GRAPHICAL=1 DISPLAY=:99` for graphical input. It checks1.1s slow confirmation across normal polls, a real poll held outstanding while confirming/repeating, one action send, an ability target across polls, remote player change, explicit reconnect, cancellation while reserved, and a validated same-step/different-hash edge fixture. Only that final alternate snapshot is synthetic; polls and ordinary commands use actual fsnet.
