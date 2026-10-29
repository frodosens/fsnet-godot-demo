# Latest map animation rollout

User requested all available new map animations and removal of animation-version switches. This replaces earlier opt-in/default-OFF and explicit-OFF-persistence policy. It does not authorize new generation or claim missing generic caster assets exist.

## Selection

| Actor | Movement | Stopped idle |
|---|---|---|
| Mara / Finn / Neri | Seedance Mini V2, mirrored right views | Same V2 profile static idle |
| Oren / Bram | Accepted compact sequence | Accepted compact sequence |
| Tessa | Accepted padded motion-only sequence | Existing idle |
| Adela | Accepted two-panel mirrored motion | Existing accepted animated idle |
| Elsbet | Accepted Mini retry, 20/30 weighted ticks per grid | Existing accepted animated idle, never replaced by new static guards |
| Rodd | Mini V1, mirrored right views | Padded original canonical idle with matching mirroring |
| Vera | Existing chapter-three motion | Existing canonical idle |

Each move still uses actual distance and one gait cycle per grid; no Lua/native rules, movement speed or campaign changes. Identity guards and missing/invalid-resource fallback remain. Old asset files are retained. Internal in-memory setters remain solely for existing fallback QA; they have no UI or saved preference effects.

## Configuration compatibility

The animation-version controls and their scroll area are removed. Existing animation preference keys (including versioned Neri OFF) are ignored and left untouched on disk. Fresh settings and restarts select latest resources. No new migration stamp or destructive preference rewrite is needed. Health-bar avoidance still loads/saves normally; lighting, sound, volume and reduced motion remain available. Existing unrelated settings are not silently reset by animation migration.

## Visual limits

Rodd is enabled because the user explicitly requested all new resources despite the disclosed 3D shoe-bottom clipping. That clipping and the one-source-pixel old-right-idle alignment difference are NOT fixed here. No depth-disable, global bias, per-frame offset or body squash is included. Rodd's generated body height/detail/style differs slightly from the canonical idle.

Elsbet retains the accepted more rear-on back view, mirrored equipment handedness and the pose/style transition back to old idle. Padding alone does not guarantee every sole pixel clears 3D ground. Other previously disclosed gait sliding, seams and thin sole trimming remain. This rollout does not claim natural or perfect gait.

## Review boundaries

Animation candidate is isolated from character-details/XP changes. Main is not updated by this work. Linux graphical and actual authority/client tests are required; no Android/Windows device validation is claimed. Captures stay local, not in Git.

## Author validation for this revision

111 unique Godot test scripts passed (74,272 counted assertions), with changed fixtures rerun after updates. Additional separate-process latest-policy validation: 222 checks; three Neri legacy-version restart phases passed. Linux graphical policy: 223 checks plus 26 settings input/layout checks at both sizes. Sixteen real authority/client movement cases each observed 31 Runtime replacements (all ten actors front-right, plus the remaining three directions for Rodd and Elsbet). Both admitted 18-PNG packages match their source Git blobs exactly. No Android or Windows runtime claim.

Legacy asset tests now explicitly select retained resources so they continue checking old fallback behavior instead of assuming production defaults are OFF. Retired UI-switch assertions test absence of those controls; mouse/keyboard and board-blocking tests remain for the unrelated settings. Initial stale-fixture failures were rerun, not counted as passes.
