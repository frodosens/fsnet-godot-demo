# Reference battle presentation

The approved illustrated battle background and independent UI assets are integrated
on a uniformly scaled 1586x992 canvas. Feet use y=642; status panels start at y=756.
The background is admitted only when scenario ID, dimensions and terrain match the
reference bridge. Custom maps retain the previous generic backdrop. This checks
map compatibility, not a promise of unique art for every Mod.

Names, portraits, ability title and HP are runtime data. `combat_context.gd`
reconstructs chronological HP from the settled event batch and final unit view;
attack damage is already capped to actual HP lost, and healing uses actual restored
amount. HP switches at the same contact tick as impact feedback. Skipping only
ends presentation; it never writes rules, replays a command or rolls RNG. Missing
portraits retain the textual identity, and missing event context shows HP — rather
than invented values. Unknown skills show their stable ID.

The two controls are speed and skip. Sound and reduced motion remain accessible
through Pause → 音效与动态效果. Healing retains the existing map feedback. The
current rules have no miss/block mechanic; the UI does not fabricate either.
The original sprite/contact assets remain unchanged, including their limited
keyframe smoothness. No new normal maps or character lighting are claimed here.

Validation: 4244 checks and five three-process network/reconnect scenarios passed.
1280x800 and 960x600 screenshots were inspected. A six-role graphical recording
uses explicit adjacent-opponent fixtures and actual shared-Lua commands, including
one guaranteed-crit fixture; this is not an ordinary uninterrupted playthrough.
Screenshots and videos are local/Library only, never committed into this repository.
Windows/Android graphical validation remains outstanding.
