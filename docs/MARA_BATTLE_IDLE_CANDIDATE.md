# Mara battle idle candidate

Isolated trial; not authorization to replace the main branch. The map idle is a
separate asset/clock and is unchanged. The Mara battle clip is `mara:right`,
restricted to unit ID `mara` in `assets/animations/idle_cycles.json`.

## Source and timing

Art source commit: `fc0bc4a936bf391ce8fcfe467e24b59efd608d9b`.
Neutral is the existing `assets/battle/mara/00_idle.png`; inhale is
`assets/battle/mara/idle/01_inhale.png`. Both are 192×160, pivot (96,144).
Sequence neutral → inhale → neutral, 320 ms per slot, 960 ms period.
No attack, hit, recovery, rule, audio or native library assets are replaced.

Only authored neutral windows can sample idle. An attacker has the first two
ticks; a defender has ticks before `release_tick - 2`. Brace, attack, hit, death,
recovery and final settle poses take precedence. The prior optional interface
also sampled the last two recovery ticks; this trial removes that override.
Clocks restart per event, use the same elapsed time/speed as the cut-in, and
freeze on tree pause and impact hitstop. Reduced motion selects neutral.

No cut-in duration or impact timing is extended. For the real Oren → Mara melee
fixture, neutral lasts 0–320 ms, inhale 320–420 ms (100 ms), then brace until
540 ms impact. At 30 FPS this yields about three inhale frames at normal speed.
Mara's own initial 167 ms idle window cannot show the inhale at 320 ms. This is
**not a complete visible 960 ms breathing cycle during every attack**, nor a new
pre-combat waiting scene. At higher playback speeds the already short change is
less noticeable. Any longer visible breathing window needs an explicit pacing
choice, not a hidden delay.

## Source-facing contract (important for future Oren art)

- Mara attack and defence: right-facing source; defender is mirrored by the
  existing TextureRect flip. `mara:right` is therefore the correct source key.
- Oren attack: `assets/battle/enemy_combat/runtime/oren/00_idle.png`, right-facing,
  would require an independently matching `oren:right` clip.
- Oren defence: `assets/battle/oren/00_idle.png`, already left-facing, no runtime
  flip; a clip derived from this file must use `oren:left` only.
- Subsequent combined-candidate integration enables `oren:left` only, as recorded
  in ALL_IDLE_CANDIDATES.md. Oren right attack and the other four characters keep
  their single-frame neutral fallback. Missing clips never switch identities.

## Reproduction and acceptance

Run `godot --headless --path . --script res://tests/test_battle_idle_candidate.gd`
and `bash tools/test.sh` after importing resources and building the existing
Linux native dependency. Dedicated checks exercise real shared-Lua player attack
then AI turn, mirrored defender, old actor fallback, brace/hit/recovery priority,
reduced motion, actual paused tree, 1×/2×/4× processing, duplicate event filtering,
consecutive events, skip and unchanged snapshots. Death is a labelled presentation
fixture; it does not introduce a counterattack or any new combat rule.

Review recording uses an adjacency-adjusted reference map fixture with real Lua
commands. Repeated segments explicitly replay already settled events, without
additional damage. Capture uses Godot movie mode at 30 FPS simulation timing on
Linux 4.6.3 / llvmpipe; rendering wall time is slower and not a performance result.
Recordings/screenshots remain outside Git and are delivered through Library.

Remaining visual limitations: subtle two-pose motion, about one source pixel of
boot variation, and the existing neutral/brace/hit pose changes. No Windows runtime
validation and no claim that other characters' battle idle animations are done.

## Transparent-edge review

Metadata correction `db139d838a7fd1cee21102aae1f154b7cb7bce02` distinguishes
thresholded silhouette bounds from the actual nonzero-alpha bounds (20,48,162,160).
The image was not edited. There are 21 nonzero-alpha pixels outside the previously
reported threshold box, maximum alpha44. Same-frame defender-visible/hidden
captures at1280×800 and960×600 show faint edge residues; sampled isolated pixels
below source y143 differ by at most1/255 RGB against this background. The boot
position still has roughly one source pixel of variation. These findings do not
prove perfect alpha cleanliness on every background; no whole-character crop,
position correction or unapproved alpha threshold was applied.
