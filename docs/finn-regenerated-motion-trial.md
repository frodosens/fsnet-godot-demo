# Finn regenerated movement trial (2026-10-28)

This candidate replaces only Finn's existing opt-in motion profile source with
`assets/sprites/iso4/finn_video_regen_20261028/`. The 32 PNGs are copied unchanged
from reviewed staging commit `b07a7190f59c548981616271a88eaa62f2a794a1`; the source
manifest preserves their hashes and extraction contract. No Neri art is included.

Eight frames per direction use source indices 42,45,48,51,54,58,61,64, ending before
67; weights are 3,3,3,3,4,3,3,3 (25 total), canvas 128x128, root (64,120). Playback
uses the existing distance-normalized sampler: one grid of actual travel is one
cycle. It does not change movement speed, rules, network events or camera-facing
mapping. The manifest's source-video duration is provenance, not a runtime speed.

The existing `finn_motion_preview` setting remains default OFF. Original Finn idle,
neutral guards and `finn_video_compact` resources remain intact. Disabling the
setting restores the old nonexperimental presentation; reverting Finn's profile
paths/weights restores the previous experimental clip. Invalid/mismatched profiles
retain the existing guarded fallback. The source manifest is explicitly excluded
from exports, while runtime PNGs/profile remain exportable.

Visual inspection of all 32 frames: slight bow/hand contour breathing and foot
passing overlap remain. These are a bounded usable-frame trial, not final art
acceptance. Front/back-left/right source labels are bound without remapping;
independent visual direction auditing remains a separate task.

Validation uses `test_finn_regenerated_source.py`, the Finn sequence/scene/edge
suites, four-direction walk tests and the real local authority/client walk test:

```
AMBER_WALK_ACTOR=finn AMBER_COMPACT_SEQUENCE=1 python3 tests/run_walk_network.py
```

The edge test now selects through the current public actor-selection API instead
of directly changing selection fields while pending selection presentation exists.
This is fixture alignment with the already-reviewed default-Move behavior.

Actual in-game video uses `tests/record_finn_sequence.gd`, four legal direction
fixtures, the normal simulation speed and Godot's fixed-24-fps movie capture.
It is Linux llvmpipe rendering, not Android device footage or a performance claim.
Videos/stills remain outside Git; runtime art PNGs are the intentional exception
for this source/art candidate. No APK or public release is authorized here.
