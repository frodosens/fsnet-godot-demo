# Adela / Elsbet: optional presentation profiles

These are reserve **art profiles**, not new classes, recruits or story characters.
The default campaign, six-character roster, content hash, Lua rules, networking
protocol and native binaries are unchanged. Ordinary character production stops
after these two. No cancelled composited map-idle work is included.

## Use through the existing Mod editor

From the level editor choose **导入 JSON**, open
`docs/examples/reserve_art_demo.json`, then use its existing save/play controls.
The example is a legal data-only Mod that replaces two unit identities with
`adela` / `elsbet`, retains existing knight / raider rules and has no story events.
Both are player-controlled for inspection. This choice of rules is a test carrier,
not a new profession assignment. Custom Mod terrain keeps the normal 3D fallback;
the example does not force the reference painting onto a different map identity.

An author can instead use those exact IDs on units in their own valid Mod, choose
an existing legal `role`, and set name/stats/skills with the existing schema.
No `art_id`, script path or new gameplay field is introduced. Unknown IDs retain
the original role-art/portrait fallback. IDs remain unique within a battle, so
this minimal interface does not support multiple same-ID copies in one roster.

## Loading and playback

`view/reserve_art.gd` resolves the two bundled manifests under
`assets/characters/reserve/{adela,elsbet}/`. Portraits use the same resolver across
the status dock, target preview, story and combat cards. Map profiles override
only these identities, not every unit with the same role. All four diagonal
images are static both during idle and path movement. Camera-facing projection,
ground anchor `(48,120)`, lighting, shadows and existing size calibration remain.
An unrelated generic map-idle clip cannot activate breathing on these profiles.

Combat uses the right-facing 192x160 originals; the defender is horizontally
mirrored, including the semantic impact coordinates. This mirrors handedness;
there are no independently drawn left-facing combat assets. Each profile has two
idle poses, three independent attack poses (neutral/anticipation/contact), reused
anticipation for attack recovery, and one new hurt pose followed by neutral.
Only basic `attack` events use these melee clips. Other skills retain their real
rule effects without inventing unsupported bow/magic cut-in art for these IDs.

The existing 24 ticks at 60 ms and melee contact tick 9 are retained for the new
clips. The manifest's longer preview holds are **not** runtime delays. Defender
breathing changes at 450 ms: it is visible during Mara's longer windup, but not
before the 420 ms brace threshold of the shorter melee sequences. The attacker's
120 ms neutral opening cannot show an inhale. No waits are added to hide this.
Hurt, death and recovery take precedence over idle; speed, skip, pause and event
deduplication use the existing cut-in lifecycle.

## Contact calibration and limitations

Adela wields a **spear**, not a sword. Its source tip is `(186,80)`; Elsbet's high
staff tip is `(155,60)`. Integer measurements denote pixel centers, transformed
as `x+0.5` and mirrored continuously with `192-x`. New contact helpers preserve
the `(96,144)` feet baseline. Elsbet targets the head, not a torso point that would
raise or lower her whole body. Original six hurt images were inspected to select
head pixels at y=60; these extra anchors apply only to her high strike and do not
modify existing characters' contacts. Tests check opaque victim pixels as well
as coincident screen sockets and unchanged attacker/defender baseline heights.

This is a small-keyframe candidate, not full hand-drawn smooth combat animation.
Adela's contact pose has a one-pixel solid-foot difference. Faint low-alpha portrait
residue and small edge changes remain in the original delivered files. The source
art, provenance and hashes are retained without alpha cleanup or redraw.

## Reproduce validation

Run `tools/test.sh`, including `tests/test_reserve_art.gd`. The dedicated test checks
existing Mod import/storage, portraits, all map facings, static movement, save/load,
real attack events, new-versus-original contacts, mirrored hurt/idle, pause, skip,
speed, duplicate events and unchanged default content. For the smaller graphical
window, set `AMBER_RESERVE_SMALL=1` and run that test with an actual display.

The example also works with the existing three-process reconnect harness:

```sh
AMBER_TEST_WAIT=1 AMBER_MOD="$PWD/docs/examples/reserve_art_demo.json" python3 tests/run_network.py
```

For a local actual-runtime clip, use Godot Movie Maker at 30 fps with
`--script res://tests/record_reserve_art.gd` and an absolute `--write-movie` path
outside the repository. Its opening direction turntable is explicitly labelled
an art inspection; movement and attacks then consume legal Lua commands. The
recording is fixed-step normal simulation, not a hardware performance benchmark.
Do not commit generated screenshots, recordings or build caches.

Linux Godot 4.6.3 / Mesa llvmpipe is the available visual test platform. Windows
native bundle identities can be checked, but Windows visual execution is not
claimed by Linux tests.
