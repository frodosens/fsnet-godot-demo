# Test entry points

First conservative split (2026-10-30). Runtime code and assets are unchanged.
Use an isolated worktree for the PowerShell runner: its existing cleanup restores
tracked `.import` files, including pre-existing edits. This cleanup is not fixed
by this test-only change. Never run it over your uncommitted import settings.

## Development and release

- Default headless development: `bash tools/test.sh` or
  `pwsh tools/test-headless.ps1 -Godot <godot>`.
- Focused edit: `pwsh tools/test-headless.ps1 -Godot <godot> -Filter 'test_target*'`
  (Python asset checks and import still run); add `-SkipImport` only with an
  intact cache and no resource/import changes. On Bash, invoke the chosen test
  through `python3 tools/run_checked.py godot --headless --path . --script
  res://tests/test_target_confirm.gd`.
- Presentation/fallback changes: add `--extended` / `-Extended` to include the
  four matrices listed in `tools/test-extended.txt`. They remain available
  individually using the checked runner.
- Networking changes and release: `bash tools/test.sh --extended --network`.
  This preserves the complete existing real multi-process suite, including
  actor/direction Runtime replacements, command confirmation, replay/reconnect,
  progression caps, equipment, story and map spells. PowerShell's existing
  `-IncludeNetwork` is only a smoke check, **not** equivalent to this full gate.

Always keep golden determinism, command validation, current saves, progression,
HUD/input, and relevant network coverage. Moving tests to a deliberate entry
point does not make their failures optional. No failure patterns or assertions
in retained checks were relaxed. The default remains a broad regression suite,
not a promised sub-minute smoke suite.

## Removed / retained coverage

| Change | Evidence and retained protection |
|---|---|
| Remove second normal-mode `test_latest_map_policy` invocation | Same script, arguments and environment already run in the main loop. Separate-process `LATEST_MAP_RESTART=1` remains and is also included in the PowerShell gate. |
| Delete old save migration assertions in `test_progression` and `test_progression_save` | User explicitly excludes old save compatibility. Current snapshot round trips, XP settlement/cross-chapter inheritance, failed checkpoint writes, invalid campaign data and admission atomicity remain. Corrupt-file test now tampers a current save. |
| Delete historic occupied-cell save/load block in `test_lantern_obstacle` | Keep current obstacle legality, BFS, authority/replica agreement, current save/load and custom-map fallback. Content-version network mismatch stays. |
| Remove predecessor-rules acceptance assertion | `test_unit_instance_state` checks current rules plus unknown-rules rejection. `test_unit_legacy_parity` still checks all golden commands, events, snapshots and round trips; only its save-compatibility hash acceptance condition is removed. |
| Remove 128 deleted-toggle combinations from `test_idle_only` | Latest policy and restart already check obsolete OFF preferences cannot disable current profiles. Keep weighted idle timing and all malformed profile/flag fallback cases. Settings preferences are distinct from game-save compatibility. |
| Move `test_walk_direction_batch`, `test_all_idle_candidates` to extended | Both explicitly force `legacy_map_fixture`: retained fallback/old-art matrices, not the shipped profile selection. Their assertions remain unchanged. |
| Move `test_generic_runtime`, `test_hero_refresh_scene` to extended | Exhaustive current render/profile matrices remain unchanged; focused generic instance/admission/combat, hero contracts/edges/preferences, latest policy and asset integrity stay in default. Run extended for presentation changes and releases. |
| Make Bash's complete network tail explicit (`--network`) | No network commands removed; separate-process preference checks stay in the default headless gate. |

No runtime compatibility implementation, gameplay, assetgen, assets, native
libraries or strict error detection changed. No test is removed just for having
`legacy` in its name. Historical baseline totals are not coverage requirements;
review the named behaviors and explicit suite membership instead.

## Measurement scope

See the accompanying review result for paired local measurements. The 645-second
Windows run in `BASELINE.md` is historical; it is not a measured before/after
result for this Linux change. Import, networking and the untouched default tests
must not be counted as measured savings unless timed in the same comparison.

Local bounded measurement on 2026-10-30, Godot 4.6.3 headless/Linux, same isolated
worktree and cached import, subprocess wall time (one run each; no statistical
speedup claim):

| Modified test | Before (s) | After (s) |
|---|---:|---:|
| progression | 0.929 | 0.678 |
| progression_save | 1.128 | 0.642 |
| unit_legacy_parity | 1.264 | 0.905 |
| unit_instance_state | 1.148 | 0.636 |
| lantern_obstacle | 4.010 | 3.184 |
| idle_only | 10.087 | 7.974 |
| Total for these six only | 18.566 | 14.019 |

The four unchanged extended matrices passed in 31.434, 2.873, 57.552 and
40.976 seconds respectively (132.835 s total). These are observed removed default
workloads, not a measured full-suite speedup; a lightweight runner-selection
mock overlapped part of the latter measurements. Import was 18.168 s and is
excluded. The final addition of an explicit current format=3 assertion was
verified separately. No full before/after suite or Windows timing was repeated.

Runner selection was executed with fake subprocesses, not real generation or
network calls: default 159 invocations, extended 163, release 288. Comparing
command **and environment** multisets with the previous Bash runner showed only
one removal (the duplicate normal policy); the default/extended difference is
exactly the four retained matrices. Real focused engine tests and checked-runner
fault injection were run separately. PowerShell is not installed on this Linux
host; its changes were inspected, not executed on Windows.
