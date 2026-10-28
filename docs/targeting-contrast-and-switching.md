# Targeting contrast and command switching

Attack distance is orange-red; hostile skill distance is violet; friendly/self
skill or item distance is teal-green. Distance cells have a dark keyline plus a
colored edge. Only Lua-approved targets receive ivory corner brackets. Gold fill
marks the effect footprint; an invalid hovered target has a red cross. The
existing stronger selected-target frame remains separate. These are ground
meshes with normal depth testing, below actors. Movement range opacity and all
shared rules remain unchanged. Palette classification uses the resolved ability's
actual target category, including item abilities, rather than item names.

Commands remain visible during Move or other targeting. Confirm/Cancel occupy a
compact strip above them. Changing a command clears pending move/target/path and
queued confirmation. Actor selection/camera centering is not re-run. The dock
alone owns action visibility: an old per-frame hide/show assignment canceled
held button gestures and has been removed.

A mouse/touch gesture starting and ending outside the skill/item picker closes
it without activating the underlying controls or map. An inside-origin drag does
not dismiss it. Outside the full-description layer returns only to the picker.
Canceled touches do not dismiss. Native touch-release bookkeeping remains intact
so the next map tap previews normally; synthetic mouse cannot submit map actions.

## Validation

`tests/test_targeting_command_switch.gd` uses actual Input events (not direct
button callbacks), mouse and touch with mouse emulation, at 2400x1080 and 960x600.
It checks Move→Skill/Item/Attack, stale proposal removal, camera/state preservation,
full-description backstack, drag-out/canceled touch, outside dismissal over the
underlying Wait control, reopening, first-map-tap preview and second-tap single
submission. Synthetic touch on Linux is not Android-device verification.

Relevant regressions: mobile targeting, picker handoff/full text/dynamic lists,
selection/camera, target confirmation, story footer, bottom dock, route art,
health/scene scaling, mobile camera and real three-process target-confirm polling.
Actual fixed-background and 3D captures use legal deterministic target placement
in a temporary test fixture. Captures and logs are not runtime assets and are not
committed. No screenshots, video, native binaries or production content changed.
