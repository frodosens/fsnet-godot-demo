# Default scene entry

Fresh App instances now use `scene_renderer = "auto"`. Ordinary New Game opens the authored reference bridge with the illustrated background when the existing adapter validates the scenario ID, dimensions, exact terrain and the 1280x800 background texture. Missing or incompatible art, legacy default.json, custom maps or changed terrain fall back to 3D. No rules, map cells, save format or network hashes change.

The pause menu retains the explicit 3D/fixed switch. It sets a presentation-only session preference; new scenes and loads within that running session respect it. There was no persisted renderer preference in the previous version and none is invented or migrated. Existing saves contain content and deterministic state, so an authored reference save gets automatic illustrated presentation on a fresh process; an incompatible Mod save stays 3D.

`test_default_renderer.gd` uses a real main-menu mouse button event, then checks default illustration, character shading, six contact shadows, four painted local lights, save/load unchanged snapshot, explicit 3D preference and changed-terrain/legacy fallback. The gallery and bottom-dock capture scripts now assert that the default adapter is active instead of enabling it for screenshots. The fixed-background regression separately verifies picking against the geometry contract across seven viewport sizes. Existing ground-overlay/lights tests remain required.

Linux Godot 4.6.3 full regression and actual OpenGL Compatibility gallery are exercised; this does not validate Windows or replace clean native bootstrap requirements. No media is committed.
