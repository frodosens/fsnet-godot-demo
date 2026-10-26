AMBER BRIDGE — RANGED / MAGIC BATTLE KEYFRAMES BATCH 01
Original built-in imagegen art, 2026-10-26, aligned to approved restrained v2 palette.

Finn: 8 distinct poses (idle, nock, half/full draw, release, followthrough, lower, settle).
Neri: 8 distinct poses (idle, anticipation, raise, charge, cast, followthrough, recover, settle).
Character PNGs 192x160 RGBA; foot center (96,144); facing right. Common per-role nearest scale, alpha-component isolation. Weapons and clothing change with actual limb/body posing. No generated drawings were replaced by programmatic geometry. Source originals and exact prompts included.
6 separate VFX layers: arrow, gather, charge, bolt, impact, dissipate; 64x48 RGBA centered (32,24). Effects have discrete small pixels and no blur/bloom.

Manifest paths are relative to this asset folder. At 60ms per tick, 24 ticks explicitly hold only 8 drawings per character. Release/cast event at tick12; projectile movement/hit synchronization belongs to engine and must not apply damage from visual scripts. Source body facing and planted foot anchor remain fixed; engine may place attacker at its stage anchor.

QA: source and normalized contact sheets visually inspected; consistent Finn left-hand bow and Neri staff hand across the sequence; minor generated face/hair and cloak-fold variation remains. Neri staff swings over shoulder, requiring its full padded frame; do not tight-trim runtime. Alpha threshold16 removes almost-transparent source residue without repainting. Connected component extraction retains bowstring and staff.

First playable sparse keyframe animation, not release-fluid animation. GIFs are timing diagnostics, NOT gameplay captures or 24 independent frames. Engine playback, handedness/motion readability in final presentation, projectile anchoring, hitfreeze and runtime acceptance still required. No enemy-specific hit/death frames in this batch; retain existing Oren hit/brace/recover set. No claim that all game animations are complete.

Original game art: no third-party game sprite assets copied. Distribution license to be specified by repository owner, not silently assumed from code MIT.
