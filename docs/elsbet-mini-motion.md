> Superseded rollout policy: see [latest-map-animations.md](latest-map-animations.md). This branch combines accepted Rodd and Elsbet runtime admission, enables latest resources, and removes animation-version options. The independent OFF trial below describes candidate 92af911 only.

# Elsbet movement-only trial

This candidate is based directly on main `1ad8e604`; it does not include the held Rodd animation candidate or character-details/progression work.

## Admission and behavior

- Runtime PNGs are byte-identical to accepted art commit `f03a7026be5ec379da356b790ff466cc544f59a7`: 16 movement frames and two padded canonical idle guards. Provider task metadata is omitted from the runtime receipt.
- The 160×160 canvas has root (80,144). Front-left and back-left are source views; right views mirror the corresponding left clip. Front holds total 20 ticks, back holds total 30 ticks. Both map one cycle to one grid of actual travel; logical movement speed is unchanged.
- Only Elsbet movement uses the new frames. Stopping, skipping and invalid-profile fallback retain the existing canonical or animated idle chosen by the existing idle preference. New padded idle guards are not installed as stopped idle.
- Pause → 音效与动态效果 → 埃尔丝贝特镜像移动（试验） is independent and defaults OFF pending independent visual review. ON and explicit OFF persist. Changing it does not reset another actor or Elsbet’s stopped idle clock.
- Source identity guards reject unrelated Mod portraits/sprites. No campaign spawn, gameplay rule, portrait, battle animation or equipment changes.

## Validation and limits

Dedicated tests cover all four facings, two viewport sizes, fixed and 3D scenes, both existing idle settings, initial motion root, weighted travel, turn/stop/skip, rollback, ghost, camera and snapshot stability. Real authority/client tests check phase through repeated Runtime replacements and the continuing old idle clock after stopping.

Actual local captures include all four directions, turns and old/new transitions at 1280×800 and 960×600 in fixed and 3D modes. These fixed-step captures show gameplay presentation, not real-time performance. No capture media is stored in Git.

The user accepted the more rear-facing back angle. The new walking style differs from the retained idle, so stopping can show a pose/handedness change. Floor depth testing remains enabled: source canvas padding is not proof of complete sole visibility in every 3D frame or occlusion. No depth bias, per-frame recentering, body shrink, or global renderer workaround is included. Independent visual acceptance remains required before changing the default.

The old `test_reserve_art` assertion “moving uses matching static direction” also fails on unmodified main; do not count this baseline failure as a successful check or hide it by changing the assertion here. Linux only; no Android/Windows device validation.
