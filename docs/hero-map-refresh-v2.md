# Three-hero map refresh V2

Scope: Mara, Finn and Neri map visuals only. No portrait, cut-in, story, roster,
equipment, damage, movement-speed or networking-rule changes. The three independent
`地图重制 V2（试验）` settings are appended to Pause → 音效与动态效果.
They remain **off by default pending independent runtime review**. Each preserves
and restores the corresponding legacy options; Neri's existing default-on mirror
preference is not migrated or overwritten.

## Asset and renderer contract

The 54 PNGs exactly reuse art commit `33ac83366ce2e7a5fb6756730f184a4eb2c59cea`.
Only the Mara/Finn art-manifest `zero_alpha_rgb_zero` flags are corrected to false:
four completely transparent pixels contain hidden RGB; source PNG bytes are not
rewritten. There are 16 walk and two static idle PNGs per hero, 160×160 with root
(80,144). FL/BL are originals; FR/BR share their matching textures with `flip_h`
for both idle and motion. No breathing animation is claimed.

Version2 profiles are restricted to the three IDs and require the explicit canvas,
matching idle/motion mirrors, one idle frame and valid weighted clips. Original
neutral texture guards remain. Version1 96/128 canvases and Tessa's 128×136 are
preserved. Invalid/missing profiles keep legacy art.

The sprite offset is64 for the padded canvas; pixel-to-world helpers remove the
32px horizontal/24px vertical padding relative to canonical 96×128 coordinates.
Foot world coordinates, pixel size, shadows, HP position/width and camera focus
reference are preserved. The same application path handles idle updates, movement
start, direction changes, settlement/skip, refresh, rollback and ghost previews.
Ground depth testing is unchanged. Motion still samples one weighted cycle per
grid traveled, including after ordinary network Runtime replacement.

## Visual review and limits

A45.1-second real-game recording shows each hero's old FR motion, all four new
facings, stop/start and a legal corner. It uses actual shared-Lua moves from an
explicit test placement, fixed30FPS capture at normal simulation speed; recording
wall time is not a device FPS measurement. Fixed-background/3D stills at1280×800
and960×600 include lowest-foot phases, plus separate bridge captures.

Finn has the strongest cycle. Mara retains a modest scarf seam; Neri retains a
small cape/yaw seam. Mara/Finn idle use frame0 neutral fallback, so details can
change into the later motion style; Neri uses grounded frame22. No early facing
inversion, teleport, scale compensation or gross deformation was observed in the
sampled game routes. Mirroring consistently reverses costume/weapon asymmetry in
both states. Opaque pixels can reach y150–151 below root144: lower shoe-edge
clipping remains possible on the3D floor/bridge. Padding does not remove depth
occlusion. These are simplified held-frame cycles, not perfect foot locking.

Author recommendation: all three are suitable for independent acceptance of the
requested refresh, with Finn the strongest; disclose the above seams and floor
limit. Keep the three defaults off in this candidate until that review closes.
No automatic paid retry or further generation was performed.

## Verification

- In-memory invalid/legacy schema tests, actual PNG hashes/paths and profile bindings.
- Independent preferences, rollback, legacy Neri default and unknown IDs.
- Four directions × three heroes × two view modes × two resolutions: weighted
  frames, fixed roots, scale, HP/ghost, speed0, same-step refresh, skip and rollback.
- Legal corner, same-state VM replacement, large delta, malformed fallback and
  unrelated idle-clock isolation.
- All existing headless scripts plus actual graphical scene/settings tests.
- Twelve actual authority/client hero routes, each with31 Runtime replacements;
  existing five network groups and three-process target confirmation.

Only Linux/Godot4.6.3 was exercised. No Android device/APK was built. Captures and
logs remain outside Git. Fresh-clone import/export-pack integrity is checked
separately; no production instrumentation is included.

Recorded candidate checks:101 headless test scripts /69,795 assertions,270 source
integrity checks,4,647 graphical scene/edge/settings assertions; all passed after
keeping legacy settings in their original order and appending the three new
switches. Existing five network groups, target-confirm27 and12 new hero network
routes passed. A no-local-cache clone imported all assets, passed4,512 scene
checks, and produced an Android-preset PCK containing all54 PNG resource entries
and six JSON manifests. This verifies resource packing only, not an Android build
or device launch; the clean clone reused the already-built Linux bridge library.
