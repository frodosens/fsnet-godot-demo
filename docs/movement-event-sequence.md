# Allied traversal and ordered enemy presentation

This candidate changes movement rules: living units of the **same faction** may
be traversed, but no living unit's cell may be a destination. Other factions
remain blocking. Controller and the legacy `ally` display flag do not establish
friendship. Defeated units do not occupy cells. Terrain and movement cost stay
unchanged. Lua's internal BFS retains transit nodes and parent links; public
reachable cells contain only legal landing cells (plus the mover's origin).
Preview, command validation and AI use the same search. AI must also select an
empty destination.

The previous renderer started every move in an `end_turn` batch together, then
played the batch's attacks. Lua had already emitted the actions sequentially.
`view/event_sequence.gd` now presents each immutable move/attack/heal event in
order. Completion comes from the existing movement/cut-in/heal presentation,
not an added timer. Temporary visual positions and HP are reconstructed from
the settled batch; later actors remain at their starting cells until their own
events. The authoritative Runtime, command ordering, RNG and final state are
never changed by this presentation queue.

Input remains gated for the whole queue. Ordinary same-step network Runtime
replacement does not restart it. Observed consecutive steps queue in order.
If reconnect skips steps, old presentation is discarded and only the latest
available batch is presented; missing historical animations are not invented.
Skip settles all remaining presentation to current authoritative state. Scene
restart resets the step gate. Cut-in's own skip still skips its current event,
then the queue continues. Existing speed controls retain their scope.

## Save and protocol compatibility

The Lua rule source hash necessarily changes. Live peers and command replay
continue to require identical rules. The one reviewed predecessor hash
`ff0209fc228021e6c2a82a3a4858fe20e26996d3e0b75f3a16966125a7855ca5`
is accepted **only for saved canonical v5 snapshots**, whose layout is unchanged.
Inventory, RNG, positions, story and checkpoint bytes are preserved on load.
Subsequent commands use the new traversal rules. This is not a promise that an
old command log produces the same outcomes under new rules. Unknown save hashes
remain rejected; no relaxed network handshake is introduced.

## Reproduction

- `godot --headless --path . --script res://tests/test_ally_traversal.gd`
- `godot --headless --path . --script res://tests/test_event_sequence.gd`
- `python3 tests/run_event_network.py` starts a real authority and client,
  traverses two allied cells, then observes the ordered AI events across ordinary
  network Runtime replacements and compares with offline canonical state.
- `godot --path . --script res://tests/test_event_sequence_input.gd` exercises
  actual mouse end-turn confirmation, gated clicks and restored input at
  1280x800 and 960x600. Use an available graphical display.
- `bash tools/test.sh` includes the rule/queue/network tests and existing suite.

Validation environment: Linux Godot 4.6.3; graphical checks use Compatibility
and llvmpipe. This is not a Windows or Android runtime claim. The demonstration
uses legal test placements on the reference terrain and an actual Lua end-turn
command, not an unmodified chapter playthrough. Its 60fps movie capture advances
normal fixed simulation time, independent of capture throughput. Demonstration
media stays outside Git.
