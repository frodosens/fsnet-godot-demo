# Bottom dock: functional groundwork (unpublished work branch)

Exact approved reference art has not been materialized in this environment. No new dock art/layout is claimed implemented. The measured 1586×992 rectangles supplied by the design worker are retained for the later integration; shared HUD must use source 01, movement context source 02.

Implemented independently:
- Shared Lua `wait` command exhausts only the selected live player unit's movement and action. Fully spent units, enemies, stale/duplicate commands are rejected atomically. No RNG draw or AI phase occurs. Existing snapshot fields persist the result.
- Move destination selection is a local proposal carrying actor ID, authoritative step and exact Lua BFS path. Only confirm submits. Confirm revalidates actor/step/path, clears the proposal before sending, and blocks duplicate confirmation. Cancel/reselection/pause-save/authoritative step changes invalidate proposals. Proposal state is never saved or transmitted.
- Temporary existing UI: Enter confirms a staged destination, Esc/right-click cancels, 5/W performs wait. These are functional hooks, not final bottom-dock controls. Exact-art Confirm/Cancel/Wait buttons remain to be integrated and visually validated; no touch-device claim.

Compatibility: rule source hash changes because wait is new. Existing peer and save checks intentionally reject old-rule data with a clear incompatibility error and retain the old save. There is no silent migration or overwriting. Tests cover this policy.

Regression coverage includes three independent Lua runtimes agreeing on wait, wait snapshot restore and reset on next turn, invalid/duplicate rejection, RNG invariance, proposal confirmation/cancellation/reselection/save/staleness, real UI keyboard confirmation in the full victory/defeat/save/load flow, and an extra three-process fsnet reconnect fixture transmitting wait commands.

Keep this branch unpublished until actual reference crops are viewed and the full dock is integrated. Screenshot/video delivery remains native chat only; none are added by this groundwork.
