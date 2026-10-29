# Headless baseline (Windows)

Recorded 2026-10-29 on this machine. This is the regression gate every refactor
step must keep green; it replaces "I ran the tests once" with a reproducible
11-minute run and a CSV report.

## How to run

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-headless.ps1 `
  -Godot  'G:\Godot_v4.6.1-stable_win64\Godot_v4.6.1-stable_win64_console.exe' `
  -Python 'C:\Users\frodo\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'
```

The script targets Windows PowerShell 5.1 as well as PowerShell 7.

Useful switches: `-Filter 'test_bridge*'` for a subset, `-SkipImport` to reuse an
existing import (only safe when the import cache is intact), `-KeepLogs` to keep
every log, `-IncludeNetwork` to add the fsnet loopback smoke test (currently red,
see below), `-Out` to move the CSV report.

The script:

1. redirects `%APPDATA%`/`%LOCALAPPDATA%` to a temp directory, so the engine
   never writes into the real profile (a read-only profile used to crash startup);
2. imports the project (`--headless --import`, ~30 s) on every run: the
   `AmberLogic` GDExtension class is only registered after `extension_list.cfg`
   exists, and 915 assets have no committed `.import` metadata, so the importer is
   what makes them loadable;
3. runs the python checks and every `test_*.gd` listed in `tools/test.sh`
   (that file remains the single source of truth for the list);
4. fails a child that exits 0 but printed `ERROR:`, `SCRIPT ERROR`, a `FAIL`
   marker or a non-zero `failures=` count, mirroring `tools/run_checked.py`.
   Engine messaging that is not an assertion is allow-listed: the root
   certificate query on Windows, VSync on the dummy renderer, and the renderer
   shutdown diagnostics Godot 4.6.3 prints for `--headless` ("were leaked at
   exit", "PagedAllocator");
5. restores the tracked `*.import` files the importer rewrote. Generated
   metadata for the ~900 assets that have no committed `.import` stays on disk
   (deleting it makes the project unable to load its textures until the next
   import) and is `.gitignore`d, so the checkout still reports clean.

## Test harness

Every SceneTree test extends `res://tests/support/test_case.gd` instead of
copying its own `check()` (143 copies were removed):

```gdscript
extends "res://tests/support/test_case.gd"
func _initialize():
    check(value == expected, "label")   # records a failure, keeps running
    require(value == expected, "label") # records a failure and asserts
    print("SUITE checks=", checks, " failures=", failures)
    quit(0 if failures else 1)
```

Use `require` only where the test cannot meaningfully continue (the old
`quit(1)`+`assert` copies); it is accepted because the checked runner turns the
assertion into a failure even when Godot exits zero.

## Environment

| Item | Value |
|---|---|
| OS | Windows, `F:\workspace` checkout |
| Engine | Godot **4.6.3.stable.official.7d41c59c4** (the version the project declares) |
| Native runtime | prebuilt `bin/windows/x86_64/libamber.dll` (`compatibility_minimum = "4.6"`), loaded successfully |
| Python | bundled 3.x used for the asset checks |
| Import | 25 s, 1276 resources, `.godot/` ≈ 69 MB (git-ignored) |

## Baseline result

| Stage | Count | Result |
|---|---|---|
| Godot headless tests | 148 | 148 passed |
| Python asset checks | 11 | 11 passed |
| Reported assertions | 88,020 | 0 failures |
| Runtime | 645 s (10m45s) including the import pass | serial, one engine process per test |
| Slowest cases | `test_generic_runtime` 48 s, `test_walk_direction_batch` 26 s, `test_hero_refresh_scene` 24 s | |

**Rule: the reported assertion total must never go down.** It is the cheapest
guard against silently deleting coverage while moving files around.

`tests/test_golden_snapshot.gd` (added with this baseline) freezes:

- `rules_hash` — the SHA-256 of the assembled Lua rules source;
- `content_hash` — the SHA-256 of the validated default content;
- the canonical snapshot after a fixed move → skill → enemy-turn sequence;
- the byte-identical snapshot round-trip through a fresh VM.

Any accidental edit to `logic/battle.lua`, `logic/rules/*.lua`,
`logic/runtime.gd` or `content/default.json` fails this test with the expected
and actual value. Regenerate only for an intentional rules change:

```powershell
$env:AMBER_UPDATE_GOLDEN='1'
godot --headless --path . --script res://tests/test_golden_snapshot.gd
```

## Known red: network smoke

`tests/run_network.py` fails on this host after 16 s:

```
CLIENT_DISCONNECTED after_step=2
NETWORK_TIMEOUT role=driver status=Online · action 2 · sync
```

The authority stays at action 2 after the deliberate disconnect; the client never
reaches action 3. This reproduces on the unmodified checkout, is unrelated to the
refactor (which does not touch `logic/` or `native/`), and is excluded from the
gate (`-IncludeNetwork` opts in). Tracked separately.

## Engine-version side effects

The gate imports with the engine the project declares. Opening the project in a
different engine version rewrites import metadata: in one run we observed 361
tracked `.import` files touched (content identical after normalisation), 915
generated `.import` files and 242 generated `.uid` files. The tracked ones are
restored by the runner and by

```powershell
git checkout -- ':(glob)**/*.import'
```

when you run tests by hand. The generated ones are `.gitignore`d: they must stay
on disk for the project to load its textures, and they are recreated on the next
import anyway.

Installing 4.6.3 and re-recording this baseline is recommended before the
structural work that touches rendering (`main.gd` extraction).
