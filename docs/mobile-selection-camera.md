# Actor selection, bounded focus, and target readability

`main.select_actor(index)` is the common map/HUD selection entry point. It rejects
non-player/dead actors and locked or pending-network selection. A selected actor
with a Lua-admitted movement path enters Move immediately; the next destination
tap previews and the following tap confirms. Actors with no legal movement retain
the command menu. Cancel returns to that existing menu. Initial scene entry keeps
the existing menu, and explicit skill/item choices take precedence over automatic
Move. Wait auto-next, death fallback, and the next round reuse the same behavior
after presentation/input locks clear.

Only a changed actor identity requests camera focus. The mobile authored-scene
adapter uses a 280 ms smooth interpolation toward the sprite's displayed center,
clamped to its existing cover-pan bounds. UI transforms do not change. Map touch
press interrupts focus before hit testing; dragging also cancels it. Repeated
refreshes and equivalent network Runtime replacements do not restart focus.
Reduced Motion focuses immediately. Desktop fit and custom non-authored views
retain their existing camera behavior.

The existing cyan actor ring stays separate from the destination/target marker.
Selected target cells receive dark-backed gold outlines and stronger corner
segments; invalid cells use red. The subtle pulse is disabled with Reduced Motion.
All marker strokes are projected onto the same depth-tested ground plane as the
range layer, below actors. This uses procedural geometry, without new paid art.

Validation: `tests/test_selection_camera.gd` exercises raw touch with mouse
emulation at 2400x1080, 1280x800 and 1600x1200; selection, next-tap move preview,
second-tap submission, depleted movement, pan interruption, unchanged-state poll,
Wait auto-next, skill return, rule-driven actor death, next-round input, checkpoint
restore and resize/extreme bounds. Existing touch, targeting, Wait, event-sequence,
chapter and first-launch checks remain relevant. `test_mobile_touch_camera.gd`
now uses Cancel before Wait when selection has automatically entered Move.

Real Linux llvmpipe captures were inspected at 2400x1080. These are simulated
phone dimensions, not Android hardware tests or a performance measurement.
Screenshots, toolchains and APKs remain outside Git. This candidate does not
include picker redesign work or authorize a new APK release.
