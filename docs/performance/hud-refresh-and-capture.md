# HUD refresh and delivered-video diagnosis

Baseline main: `81ee7535308472bdf530600998b4b4e49dd9c1ea`. One bounded candidate removes two redundant refresh calls; no asset, cadence, gameplay, snapshot, network protocol or native change.

## What the delivered video actually contained

The Mara/Bram rear clip is H.264, 376 frames, constant 30/1 FPS, duration12.533333s. Decoding found only one identical adjacent full frame, the final closing frame375. Motion telemetry contains72 position updates per three-grid route, each advancing1.25/30 world units. N/L/N/R normally holds each pose for6 video frames (0.2s). Sparse pose changes are separate from continuous root movement and encoded frame rate.

The Godot Movie Maker log recorded those12.53 simulated seconds in40 wall-clock seconds. Its CPU/GPU/encoding fields were18.57/18.47/18.88ms averages, respectively. These are overlapping/software-renderer capture statistics, not independent physical GPU measurements. The visible FPS label reports engine throughput during recording; it does not label encoded video cadence. Capturing60 distinct rendered frames per simulated second improves root-position sampling only: it still holds each pose12 frames/0.2s. No interpolation, footage speedup or additional art poses are involved.

## Nonrecorded measurement

Godot4.6.3, Linux, Compatibility, llvmpipe LLVM19.1.7,1280x800, fixed illustrated background, six units, vsync requested disabled. No movie, fixed-FPS flag, PNG capture or video encoder ran during timing. Warm-up precedes each scenario. Offline fixture is the same legal Mara back_left content used for route QA. Online scenario uses a real local fsnet authority/client in the same application; unlike network correctness tests it is not a separate-process server.

Monotonic timers wrap named script methods in a disposable project. Values below are milliseconds, median/p95. Nested method timings overlap: do not sum them. Frame interval is measured between SceneTree process-frame signals, includes scheduler/render effects, and is not pure script or GPU time. Shared cloud hardware/power contention is uncontrolled; a single paired run does not establish a device benchmark or statistical significance.

| Scenario | Main script before | Main script after | Frame interval before | Frame interval after |
| --- | ---: | ---: | ---: | ---: |
| Idle map | 2.213 /3.082 |1.412 /1.839 |20.819 /23.961 |22.184 /25.240 |
| Selected/action menu |2.163 /3.323 |1.343 /1.851 |21.256 /26.132 |21.046 /23.927 |
| Path hover |2.307 /3.144 |1.300 /1.774 |23.093 /29.496 |22.235 /27.094 |
| Moving |2.870 /4.829 |1.485 /2.194 |23.826 /34.552 |23.017 /37.760 |
| Online sync |2.420 /5.091 |1.489 /2.224 |23.148 /37.518 |22.044 /32.564 |

The reproducible redundancy is exact:120 idle frames invoked the dock360 times before,120 after. `main._process` called both `refresh_story` and `refresh`; `refresh` called dock refresh directly and again through its final `refresh_story`. Candidate keeps the final story/modal synchronization and removes the two earlier duplicates. Direct story/modal transitions still invoke `refresh_story` immediately. Main-script medians improved36–48%; overall frame timing is mixed, so this is **not a claim that low FPS is cured**.

Other inspected paths: idle/selected maps made no measured Lua calls; hover path calls median0.114ms/p950.152ms. Network synchronization median4.089ms/p956.173ms before, including complete VM validation, about28 replies in180 frames; no unvalidated snapshot shortcut introduced. MapIdle median~0.09ms/frame, HP update median~0.012ms/unit, fixed-view update~0.04ms/frame. Path presentation~0.72ms median during hover. HP texture scans and portrait alpha scans are cached at setup/first use, not per-frame. Skins are cached, although the legacy hidden HUD still allocates companion border styles during refresh; no broad rewrite was attempted. Godot `Performance.TIME_PROCESS` was also collected, but its sampled/stale values include setup spikes and are not used as a direct per-frame script attribution.

## Reproduce without mutating the checkout

Requires the existing project Godot/native prerequisites and a usable display. No new Python packages are needed:

```
DISPLAY=:97 XAUTHORITY=/tmp/amber-display/auth python3 tools/profile_scene.py --project /path/to/checkout --output /tmp/new-profile.json
```

Use your actual display settings rather than assuming this cloud display exists. The tool copies tracked working files (excluding documentation) plus the locally built Linux bridge into a temporary project, adds named timers there, imports resources, runs `tests/perf_scenarios.gd`, writes one report with revision/dirty metadata, and deletes the disposable copy. It rejects output overwrite and symlinked tracked files. Source working files are never instrumented by this reproducible tool. The probe itself has small timing overhead; compare identical probe/scenario builds, with no concurrent capture/test load. Runtime logic tests do not depend on Python or these probes.

The optional game-dev sealed-run CLI was not installed in this environment. These are bounded native Godot probe results, not admitted/sealed hardware telemetry. Raw reports, screenshots and videos remain local/native Library, not Git. Windows and physical-GPU timing were not measured.

Reproduction-tool validation: the disposable-copy run completed independently after the first paired measurement. Main-script medians were1.410/1.310/1.304/1.419/1.503ms for idle/selected/hover/movement/online, with the expected120/120/120/61/180 dock calls. This supports the narrower script-work finding, while frame intervals still varied with the shared environment. Full regression:8,699 counted checks, five basic network variants, target-confirm network and fourteen gait network cases passed.
Actual graphical input regression also passed: story/footer76 checks at1280x800 and960x600; bottom dock53 checks. The fresh60FPS capture passed1,756 path/facing/foot/snapshot checks, encoded752 frames over12.533333s. Its higher output cadence is a capture choice, not an in-game FPS guarantee or an art-frame-count increase.
