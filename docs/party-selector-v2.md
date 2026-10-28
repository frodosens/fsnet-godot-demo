# Compact party selector and active actor markers

The right-side roster contains only existing allied player-controlled members.
Eye strips are AtlasTexture crops of the original portrait selected by unit ID;
unknown IDs use their own portrait's upper-face crop or name initials, never a
substitute identity. No HP bars are added to the roster.

The visible frame keeps its 272:120 aspect ratio and the common transparent
[23,25,226,70] eye window. It is not nine-sliced. Portraits preserve their aspect
ratio with a central crop inside that window. The visual width is about ten
percent of the safe viewport, with a separately bounded minimum 48px touch row.
Safe-area placement leaves the pause button above and bottom dock below. Many
members scroll vertically. The target-information card shifts left of the roster.

Selection uses the existing select_actor path, bounded camera focus and eligible
actor default-Move behavior. Moved portraits desaturate without disabling members
who can still act. Sword/boot indicate remaining action/movement; completed members
have a check. Selected framing and left notch identify the current member.
Touch/mouse gestures beginning in the roster cannot submit world commands or pan
the map; drag/cancel/secondary-touch cannot select. Existing keyboard/controller
confirmation shares the same guarded callback. Authoritative/presentation busy
states prevent switching. No attack, auto-next or gameplay logic changes.

One overhead arrow follows the currently presented event actor, including enemy
movement; otherwise it marks the selected actor. It sits above the HP marker and
hides rather than clamping onto interactive HUD controls. The enlarged pulsing
floor diamond remains depth-tested below sprites; reduced-motion freezes bob and
pulse. The original ring object remains for compatibility but is hidden by the
new presentation marker. Static map art retains its existing foreground-mask
limitations; no global depth disable is introduced.

All ten runtime PNGs are unchanged from the approved art package. Hashes and
transparent eye windows are checked. The original concept could not be downloaded
in this executor; visual QA therefore uses the supplied measured contract and the
actual runtime PNGs, not a claimed pixel-for-pixel comparison to that concept.
No design boards, screenshots, recordings or provider identifiers are Git assets.
This branch does not include the separate accepted-animation-defaults candidate.

Validation covers raw touch with emulated mouse, canceled/secondary gestures,
roster-to-map handoff, mouse and existing focus confirmation, moved/completed
states, 19-member presentation fixture, safe areas at 1280x800, 1920x1080,
1600x1200 and 2400x1080. A default-viewport test guards against headless screen
transform inflation. Real AI events verify enemy actor identity and queue order;
three-process networking verifies slow preview, polling, single deferred submit,
remote change and reconnect. Runtime art hashes and transparent windows pass.
Linux/Godot 4.6.3 only; no Android device or new APK verification is claimed.
