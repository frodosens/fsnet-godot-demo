---
name: character-asset-pipeline
description: Run the 2D character asset pipeline (concept → portrait → 4-direction idle/walk → engine-ready sprites) from the command line. Use when generating or regenerating character art for the fsnet Godot demo, when editing prompts / reference images / per-step models, when re-cutting sprites from an existing video or re-keying a concept, or when a task mentions assetgen, 角色资源流水线, 四方向待机/移动, sprites.json, or 去底/抠像 for this project.
---

# Character asset pipeline (assetgen)

Turns one text description into a game-ready character set:

```
description ──► concept (原画) ──► portrait (头像)
                    │
                    └──► 2×2 turnaround grid ──► idle video ──► idle sprites
                                            └──► walk video ──► walk sprites
                                                    (8 frames × 4 directions, 128×128)
```

Everything lives in a **work folder** (one project). Never edit the JSON by hand
unless the CLI has no verb for it.

## Quick start

```bat
cd J:\fsnet-godot-demo\tools\assetgen
set PYTHONPATH=%CD%

:: 1. create a character (also creates the folder)
python -m assetgen.cli new --work work --id mara --desc "像素风女骑士，红围巾，短剑圆盾"

:: 2. see what is done
python -m assetgen.cli list --work work
python -m assetgen.cli show --config work\mara\config.json

:: 3. generate everything (paid: ~¥2.5 for a full character)
python -m assetgen.cli run --config work\mara\config.json --all

:: 4. free smoke test (placeholder art, no API calls)
python -m assetgen.cli run --config work\mara\config.json --all --dry-run
```

`gui.cmd` opens the same thing as a Tk wizard (`gui.cmd mara` → `work\mara`).

## Command reference

| Command | What it does |
|---|---|
| `new --work W --id ID --desc TEXT [--name NAME]` | Create `<W>/<ID>/config.json`, seeded with the project style / reference / key colour |
| `list --work W` | Table of characters with per-step status |
| `show --config C` | Character fields, style, API, and each step's status / current run / model / reference |
| `set --config C [--id] [--name] [--desc] [--background HEX\|auto]` | Edit character fields |
| `prompt --config C --step S` | `--show` / `--set TEXT` / `--file F` / `--reset` / `--regenerate` / `--from-history RUN` |
| `ref --config C --step S` | `--file IMAGE` (copies + analyses it), `--clear`; analysis rewrites that step's prompt and calibrates `char_height` |
| `model --config C --step S` | `--set MODEL` / `--clear`; empty means "use the provider default for that kind" |
| `history --config C --step S` | List runs (`*` marks the current one) |
| `use --config C --step S --run RUN` | Make a past run current |
| `sprite --config C --step idle\|walk [--frames N] [--char-height PX] [--foot-y PX] [--period N] [--picks a,b,c] [--offset DIR=dx,dy] [--disable DIR] [--enable DIR] [--export]` | Tune the sprite rig |
| `clean --config C --step concept\|portrait [--method M] [--tolerance N] [--trim N] [--shadow/--no-shadow] [--matte-side N] [--matte-gamma F] [--matte-threshold F]` | Re-run background removal from `*_raw.png` |
| `reprocess --config C --step S` | Rebuild a step **without any API call**: stills re-key from raw, animations re-cut from the stored video |
| `export --config C --step idle\|walk` | Re-export sprites with the current settings |
| `run --config C [--steps a,b] [--next] [--only-pending] [--all] [--dry-run] [--refine/--no-refine] [--quiet]` | Generate |
| `project --work W [--set key=value] [--show]` | Project settings (style prompt, key colour, API defaults) |
| `style --work W --step S [--set TEXT\|--file F]` | Per-step style text; `--file` summarises an image or a document into one |
| `api --work W [--set key=value] [--test]` | API config and connectivity check |
| `model-fetch` | Download MODNet (24.7 MB) for stills matting |
| `gui --config C` | Open the wizard |

`S` is always one of `concept`, `portrait`, `idle`, `walk`.

## Money and cost control

| Action | Cost |
|---|---|
| `--dry-run` | **0** (placeholder art, still writes history) |
| `reprocess` / `export` / `clean` / `sprite` | **0** (local only) |
| concept or portrait | ~¥0.25 each (seedream) |
| idle or walk video | ~¥2.2 each (seedance 2.5, 5 s 480p) |
| `prompt --regenerate` | ~¥0.01 but **takes 60–90 s** |

Always confirm the prompt with the user before a paid generation.

## Matting

Two families, chosen automatically per image:

- **`chroma`** — the background is a saturated key colour (`max(R,G,B)-min(R,G,B) > 120`).
  The colour key is exact here and the network is skipped on purpose: MODNet
  labels saturated colours as foreground and leaves blobs.
- **`net`** — anything else (black/white/grey). MODNet matte ∪ colour key, then
  border-connected removal.

| Setting (`config.matte`) | Default | Meaning |
|---|---|---|
| `method` | `auto` | `auto` / `net` (MODNet) / `birefnet` / `key` / `learned` / `hybrid` / `edge` |
| `tolerance` | 30 | colour-key tolerance (raised to 80 automatically on chroma) |
| `trim` | 0 | erode N px — removes a rim the model painted in the key colour |
| `matte_side` | 1024 | network input size (512 is ~3× faster, slightly softer) |
| `shadow` | false | try to drop the ground shadow (only works on neutral multiplies) |

Sprite frames use a **separate** setting, `config.sprites.<step>.matte`:
`rvm` (default, sequence-aware) / `birefnet` (best edges, computed lazily per used
frame) / `key` (fastest) / `learned`. RVM halves frame-to-frame alpha jitter versus
a per-frame model. RVM is **GPL-3.0** — check the licence before shipping.

Compute device is picked automatically: a CUDA build of torch unlocks the GPU
(BiRefNet 18 s -> 0.28 s, RVM 0.35 s -> ~0.02 s per frame). `cli.py` logs
`抠像设备: cuda:<gpu> | cpu` on every run.

## Project / config layout

```
work/
  project.json              # style prompt, style reference, key colour, refine, API defaults
  .secrets.json             # api_key only (never commit)
  references/_project/…     # shared style images
  mara/config.json          # one character
  mara/concept/<run>/concept_raw.png   # original model output
  mara/concept/<run>/concept.png       # transparent deliverable
  mara/walk/<run>/walk.mp4             # source video
  mara/walk/<run>/sprites/…            # frame_00.png … per direction
  mara/walk/<run>/sprites.json         # geometry + the prompts that produced it
```

Steps `concept`/`portrait` write `files.image` (transparent) and `files.raw`;
`idle`/`walk` write `files.video` plus the exported frames. Later steps use the
**raw** file as their reference image so transparency never leaks downstream.

## Prompt model

Five editable slots: `concept`, `portrait`, `grid` (turnaround 2×2), `idle_video`,
`walk_video`. Every generation records the exact text used in that run's history
and in `sprites.json`.

Guards that rewrite or reject prompts:

1. **Structure** — `grid`/video prompts must keep `2 行 2 列`; `concept`/`portrait`
   must keep the key colour and (portrait) the word 头像. A vision rewrite that
   drops them is discarded.
2. **Flat background** — `concept`/`portrait` get the background clause appended
   if it is missing.
3. **No outline** — clauses containing `outline` / 描边 / 轮廓线 / 勾边 are stripped
   from every prompt and style on load **and** save. A dark rim is exactly what a
   key erases.

`refine` (project setting, default on) uses a vision model to rewrite the next
step's prompt from the produced image. Turn it off when identity is carried by
the reference image; it costs ~26 s per image and has caused layout corruption.

## Key colour

`config.background` is a hex value **or** `auto`:

- `auto` (default) — the prompts only demand "a flat single colour with strong
  contrast"; after the first generation the measured colour is written back and
  reused by every later step.
- explicit (`#00ffff`, `#ff00ff`, `#000000`, …) — the prompt names that colour.

Keying always uses the colour measured from the image corners, so an explicit
value is a *request*, not an assumption. Magenta/cyan are safest; black and white
are luma keys and will eat dark outlines.

## Gotchas

- **API key precedence**: `project .secrets.json` → `key_env` var → `ARK_API_KEY` →
  Windows user environment. `api --test` reports which one was used.
- **Empty config** (`0 bytes`) raises a clear `ConfigError`; the launcher rebuilds it.
- **MSVC runtime**: onnxruntime crashes the whole process if a stale `msvcp140.dll`
  (e.g. TortoiseSVN's) wins the load order. `cli.py`/`gui.py` preload System32's
  copy and fall back to the colour key when an unsafe one is already loaded.
- **RVM/MODNet files** live in `models/` and are gitignored; `model-fetch` only
  fetches MODNet, RVM must be downloaded separately into `models/rvm/`.
- `--all` is an alias for "every step"; `--next` picks the first step that is not
  done yet.
