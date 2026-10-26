# Player-loop validation — 2026-10-26

Baseline e85a039. Linux x86_64, Godot 4.6.3, OpenGL Compatibility / Mesa llvmpipe. No Windows visual or mobile claim.

## Actual UI input exercised

`tests/test_player_loop.gd` injects mouse press/release events through the viewport into real buttons and board picking. It does not submit battle commands directly or set health/outcomes. Read-only legal path/target queries choose the test player's decisions.

1. New Game; next dialogue line; pause and save slot one during the introduction.
2. Skip dialogue through its button; select knight skill, click its target; select another unit, open inventory and use a bandage on an ally. Supply decreases from two to one. These representative opening actions occur at full health; healing effectiveness is separately covered by rule tests.
3. Confirm End Turn; AI runs the same rule pipeline. Select heroes, movement/attack options and cells until the unmodified reference battle reaches victory, step 20.
4. Complete victory dialogue; return through the menu and save automatically. Load the terminal auto-save and verify real visible HP. Return and load slot one: step 0 and dialogue line index 1 restored.
5. Finish the intro and repeatedly confirm End Turn: defeat at step 12, defeat dialogue completed.

The first full graphical run passed 56 checks. Final regression adds terminal controls and auto-save/HP checks (61 checks). Animation/cut-in presentation is explicitly fast-forwarded with the existing skip hook between actions. Targeting is reset between test selections. This is automated UI integration, not an unassisted human real-time playthrough or a combat-animation acceptance test.

## Fixed during inspection

- Victory/defeat retained the previous “choose a target” hint. Terminal state now directs the player to save/return and disables/relabels End Turn; stale target preview is hidden.
- Loading a terminal save displayed empty/stale HP/MP because HUD data rendering depended on `usable()`, which is false after battle. Read-only character stats now render independently of action eligibility, using the first roster member when there is no active selection. Commands remain disabled.

## Evidence

- [Final actual victory-save render](ui-loop-victory.jpg)
- [Earlier victory render before terminal UI fix](ui-loop-victory-before.jpg)
- [Actual UI-driven defeat](ui-loop-defeat.jpg)

Before/after share the same rule-state victory; the loaded scene resets the local selection to Mara rather than Finn. No comparison claim about pixel-identical character orientation/selection is intended. `tests/capture_terminal_save.gd -- --save-root=<directory>` reproduces the final image from the genuine auto-save produced by the UI loop.

The 960×600 load menu was also rendered and inspected; it was already within the logical canvas. No unnecessary layout change was made based on confusing physical window pixels with the stretched logical viewport.

Final active suite: 1,550 checks, no errors, four real fsnet server/two-client/reconnect processes scenarios passed. Static directional idle movement, shared Lua sources, hashes and game content are unchanged.

## Platform delivery remains separate

The unverified Windows candidate is on `build/windows-native` at ae4918cf5ad379eafaff520ba8231ce29d4212e7, not merged with this UI fix. It uses official MSYS2 UCRT64 and pinned sources, builds actual fsnet and the shared Lua bridge, and is configured to upload a native project only after Windows headless checks. CI trigger/result could not be confirmed because Actions REST lookup returned HTTP 403; the available connector lists only PR-triggered workflows. No Windows artifact, compile success or visual runtime success is claimed.
