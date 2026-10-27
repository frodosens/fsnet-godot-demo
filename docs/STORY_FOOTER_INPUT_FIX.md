# Story footer pointer interception fix

Candidate based on9339d5c; no shared rules, native binaries or art changed.

## Reproduced failure

Linux Godot4.6.3 Compatibility/llvmpipe, actual1280×800, New Game → next dialogue.
Moving the pointer to the visible story `暂停 / 保存` button returned hovered
button `结束回合`. The story panel has z_index30, but the later-created bottom
dock remained mouse-active. Its end-turn callback was guarded, so the click was
swallowed rather than opening pause. Draw order alone did not establish input
order. The regression test fails on the baseline with this exact hover mismatch.

## Small fix

`BattleHud.refresh_story()` now synchronizes dock visibility and end-turn disabled
state after determining story/modal visibility, and refreshes dock actions on each
transition. `modal_page()` routes its visibility transition through that same
function. Hidden dock descendants cannot intercept story pointers or retain focus.
Closing pause, saving, advancing/skipping the final line restores the appropriate
controls immediately; terminal battles keep end-turn disabled. The existing top
pause button remains usable. No layering workaround or rule-command change.

## Checks

`tests/test_story_footer_input.gd` uses actual mouse-motion and button events at
both1280×800 and960×600, checks the real hovered control in graphical mode, and
covers next/skip, story pause/save, save overwrite, Esc both ways, modal continue,
unchanged story cursor/rule snapshot, explicit board clicks during story, and
end-turn confirmation/cancel after dialogue ends. The existing full player-loop
harness now moves the pointer before clicking as well.

Graphical full player loop passed61 checks: real UI skill/item commands, AI turns,
natural victory atstep20, victory save/load, saved intro cursor restore, then
natural defeat atstep12. It fast-forwards presentation animations only; it does
not assign victories, HP or rule outcomes. This is not a normal-speed video or
Windows run. Initial full regression passed5287 checks and5 network cases; two
explicit board-interception assertions were subsequently added to the focused
regression and checked graphically. No screenshot/video is committed.

The baseline deliberately failing regression printed an ObjectDB exit warning
with outstanding assertion frames. The successful graphical full-loop run did
not print that warning. This does not diagnose the separate QA-reported exit
warning or certify leak-free shutdown; memory-lifecycle work remains out of scope.
