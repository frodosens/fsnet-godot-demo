# Neri, Adela and Elsbet: optional idle-only sequences

Only qualified idle art is included. The failed new movement clips and Tessa's rejected idle are excluded. Existing movement, combat art, default roster, character scales and shared rules are retained. This is not completion of new walking animations for all actors.

## Assets and playback

Source art commit `cd1430b6b4ed1aa9ff1da93149b4152c06b8439c` adds exactly 72 PNGs: six frames × four directions × three actors. All 72 local Git object hashes were verified against the source commit. Files live under `assets/sprites/iso4/{actor}_video_idle/idle/{direction}/frame_00.png` through `frame_05.png`. All are 128×128 with root (64,120), unchanged body pixel scale. There is no new source video, diagnostic image, or failed motion in the repository.

Natural idle timing is 24 ticks per second:

| Actor | Frame holds | Loop |
| --- | --- | --- |
| Neri | 18,20,20,24,20,18 | 5 seconds |
| Adela | 12,12,8,12,12,8 | 64/24 seconds |
| Elsbet | 16,16,24,24,24,16 | 5 seconds |

`idle_only: true` is strictly boolean and mutually exclusive with `motion_only`. Every direction must contain valid idle data and must omit motion data. Invalid profiles are rejected atomically, preserving the previous presentation. The loader, resource cache and HP width cache remain shared with the existing weighted sequence system.

Each actor has an independent default-off local setting. In Pause → sound/motion settings, a bounded, keyboard-following scroll area contains all seven optional actor controls. Fixed sound/accessibility controls and the return button remain outside the scroll area. Turning on one actor does not reset another actor's phase or setting.

Movement start, unregistered movement fallback, and existing registered walking use the OLD neutral image and OLD walking textures. The new idle frame zero is only used for stationary presentation, preview ghosts and settling after movement. No new idle image is substituted into the old walk cycle. Pixel differences between old movement and new idle can therefore remain visible at transitions; they are not hidden by blending, per-frame offsets or deformation.

## Verification and reproduction

`tests/test_idle_only.gd` checks all weighted ticks, invalid profile flags/structures, and all 128 combinations of the seven persisted options. `tests/test_idle_only_scene.gd` checks all three actors and four directions in both render modes, old movement texture identity, anchors, HP bounds, pause, ghost, save/load, turns, duplicate events, moving toggles and large-delta completion. `tests/test_idle_options.gd` operates every actual checkbox with mouse and keyboard at 1280×800 and 960×600 and checks modal input isolation.

`tools/test.sh` includes these tests and three real-network idle-only movement scenarios. Network tests also observe idle clocks across ordinary Runtime replacements after movement. Actual Linux Godot 4.6.3/Compatibility captures use both scene modes/resolutions. Native code and Windows DLLs are unchanged; Windows visual execution is not claimed.

For local stills, set `AMBER_IDLE_STILLS` to an existing directory and run the scene or options test graphically. The grouped game recording is generated with `tests/record_three_idles.gd`, `--fixed-fps 60 --write-movie /absolute/local/file.avi --resolution 1280x800`. It uses labeled legal test placements, original movement, normal simulation timing, and offline Movie Maker capture; the visible throughput FPS is not a real-time hardware benchmark. Review media stays outside Git.

The source remains provisional video-derived art: subtle edge/detail shimmer and stance differences from older resources may remain. No per-frame alignment, rescale, depth override, new generation or paid postprocessing was used.

Validation record: the full suite exited 0 with 37,339 assertions, five basic network suites, 33 network movement scenarios and the real-network targeting test. Final additional checks passed: 2,210 idle-only configuration/timing assertions (including malformed companion flags), 3,138 scene assertions including extra HP/turn coverage, and 142 existing Finn motion-only assertions. Graphical scene checks passed at both resolutions, and 52 actual settings/input checks passed graphically. Each new actor's network movement scenario observed 31 Runtime replacements; its post-movement idle clock continued through further synchronization. The grouped review movie contains 2,754 frames at 60 Hz (45.9 seconds), played without speeding up simulation.
