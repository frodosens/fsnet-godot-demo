"""Turn one 2x2 four-direction clip into per-direction sprite frames.

Rules that took a few iterations to get right, kept here so the GUI and the CLI
behave identically:

* scale is measured ONCE per clip from the reference frame - per-frame
  normalisation only injects the noise of the hair silhouette as fake jitter;
* the ground line is pinned per sampled pose - the model translates the whole
  body vertically while walking, and leaving that in makes the sprite float;
* horizontal anchor is the reference frame's foot, never a per-frame value.
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image

DIRECTIONS = ["front_left", "front_right", "back_left", "back_right"]
CELL_LOC = {"front_left": (0, 0), "front_right": (0, 1), "back_left": (1, 0), "back_right": (1, 1)}
BG = (43, 58, 58)


def extract_frames(video: Path, out_dir: Path) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    existing = sorted(out_dir.glob("f*.png"))
    if existing:
        return existing
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-i", str(video), "-vsync", "0", str(out_dir / "f%03d.png")],
        check=True,
    )
    return sorted(out_dir.glob("f*.png"))


def load_cells(frames: list[Path]) -> dict[str, list[Image.Image]]:
    first = Image.open(frames[0])
    half = first.width // 2
    cells: dict[str, list[Image.Image]] = {d: [] for d in DIRECTIONS}
    for path in frames:
        im = Image.open(path).convert("RGB")
        for d in DIRECTIONS:
            row, col = CELL_LOC[d]
            cells[d].append(im.crop((col * half, row * half, (col + 1) * half, (row + 1) * half)))
    return cells


USE_LEARNED_MATTE = False   # config["sprites"][step]["matte"] == "learned"
USE_RVM = False             # config["sprites"][step]["matte"] == "rvm"
USE_BIREFNET = False        # config["sprites"][step]["matte"] == "birefnet"


def mask_of(im: Image.Image) -> np.ndarray:
    """Foreground mask for one cell.

    The key colour is now magenta, so the flat key is already exact; the learned
    matte is used only as a veto when it is enabled, because a per-frame network
    can flicker and that flicker becomes visible on the silhouette.
    """
    a = np.array(im).astype(np.int16)
    bg = a[2, 2, :]
    keyed = np.abs(a - bg).sum(axis=2) > 26
    chroma = float(bg.max() - bg.min()) > 120      # magenta screen: the key is exact
    if not USE_LEARNED_MATTE or chroma:
        return keyed
    try:
        from . import analyze

        matte = analyze.learned_matte(im)
        if matte is None:
            return keyed
        soft = np.asarray(matte, dtype=np.int16) > 96
        # keep the key's coverage, drop what the network is sure is backdrop
        return keyed & (soft | _dilate(soft, 2))
    except Exception:
        return keyed


def _dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    out = mask.copy()
    for _ in range(radius):
        grown = out.copy()
        grown[1:, :] |= out[:-1, :]
        grown[:-1, :] |= out[1:, :]
        grown[:, 1:] |= out[:, :-1]
        grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def anchor(mask: np.ndarray):
    """Foot centre x, lowest opaque row, body height (cell pixels)."""
    ys, xs = np.where(mask)
    if not len(ys):
        return 0.0, 0, 0
    y0, y1 = ys.min(), ys.max()
    height = int(y1 - y0)
    torso = float(np.median(xs[ys < y0 + 0.55 * height])) if height else float(xs.mean())
    low = ys >= y1 - 60
    bins: dict[int, int] = {}
    for x in xs[low]:
        b = int(x // 10)
        if abs(b * 10 + 5 - torso) <= 60:
            bins[b] = bins.get(b, 0) + 1
    centre = (max(bins, key=bins.get) * 10 + 5) if bins else torso
    band = np.abs(xs - centre) <= 40
    fy = int(ys[band].max()) if band.any() else int(y1)
    fx = float(xs[band][ys[band] >= fy - 6].mean()) if band.any() else float(xs.mean())
    return fx, fy, height


def render(frame: Image.Image, scale: float, canvas: tuple[int, int], reference: tuple[float, int],
           foot_x: float, foot_y: int, offset_x: float = 0.0, offset_y: float = 0.0,
           pin_ground: bool = True, background=(0, 0, 0, 0),
           alpha: np.ndarray | None = None) -> Image.Image:
    mask = (alpha > 64) if alpha is not None else mask_of(frame)
    rgba = frame.convert("RGBA")
    trim = mask.copy()
    lowest = int(np.where(mask)[0].max()) if mask.any() else 0
    trim[lowest + 1:, :] = False
    rgba.putalpha(Image.fromarray((trim * 255).astype(np.uint8)))
    w, h = rgba.size
    rgba = rgba.resize((max(1, int(round(w * scale))), max(1, int(round(h * scale)))), Image.NEAREST)
    base_y = lowest if pin_ground else reference[1]
    px = int(round(foot_x - reference[0] * scale + offset_x))
    py = int(round(foot_y - base_y * scale + offset_y))
    out = Image.new("RGBA", canvas, background)
    out.alpha_composite(rgba, (px, py))
    return out


def detect_period(cells: list[Image.Image], ref: int, count: int, canvas: tuple[int, int],
                  char_height: float, foot_y: int, lo: int = 10, hi: int = 60,
                  alphas: np.ndarray | None = None) -> int:
    """Find the gait period by comparing normalised silhouettes."""
    ref_frame = cells[ref]
    ref_mask = (alphas[ref] > 64) if alphas is not None else mask_of(ref_frame)
    ref_anchor = anchor(ref_mask)
    scale = char_height / max(1, ref_anchor[2])

    def signature(i: int) -> np.ndarray:
        img = render(cells[i], scale, canvas, (ref_anchor[0], ref_anchor[1]),
                     canvas[0] / 2, foot_y,
                     alpha=(alphas[i] if alphas is not None else None))
        return np.array(img.convert("L").resize((64, 64))).astype(np.float32)

    base = signature(ref)
    best_score, best_index = 1e9, ref + max(count * 3, 18)
    for i in range(ref + max(lo, count + 2), min(len(cells), ref + hi + 1)):
        score = float(np.abs(base - signature(i)).mean())
        if score < best_score:
            best_score, best_index = score, i
    return max(1, best_index - ref)


def export(video: Path, sprite_cfg: dict, out_root: Path, log=print,
           extra: dict | None = None) -> dict:
    """Export one animation from a 2x2 video clip."""
    frames = extract_frames(video, out_root / "source_frames")
    return export_cells(load_cells(frames), sprite_cfg, out_root, log=log, extra=extra)


def export_cells(cells: dict[str, list[Image.Image]], sprite_cfg: dict, out_root: Path,
                 log=print, sequential: bool = False, extra: dict | None = None) -> dict:
    """Export one animation from already-split per-direction frame lists.

    ``sequential`` means the cells are consecutive poses in order (image mode),
    so no period detection or resampling is applied.
    """
    canvas = tuple(sprite_cfg.get("canvas") or (128, 128))
    char_h = float(sprite_cfg.get("char_height") or 98)
    foot_y = int(sprite_cfg.get("foot_y") or 119)
    count = int(sprite_cfg.get("frames") or 8)
    available = len(cells[DIRECTIONS[0]])
    ref = 0 if sequential else min(8, available - 1)

    rvm_sequence = None
    if USE_RVM:
        from . import analyze

        rvm_sequence = {}
        for direction in DIRECTIONS:
            seq = analyze.rvm_alpha_sequence(cells[direction])
            if seq:
                rvm_sequence[direction] = [np.asarray(a * 255, dtype=np.uint8) for a in seq]
        if rvm_sequence:
            log("RVM 序列抠像：%d 方向 × %d 帧" % (
                len(rvm_sequence), len(next(iter(rvm_sequence.values())))))
        else:
            log("RVM 不可用，退回色键")

    alpha_cache: dict[tuple[str, int], np.ndarray] = {}

    def alpha_at(direction: str, index: int) -> np.ndarray:
        """Matte one cell, computed lazily - a 121-frame video only needs the picks."""
        nonlocal_alpha = alpha_cache.get((direction, index))
        if nonlocal_alpha is not None:
            return nonlocal_alpha
        mask = None
        if rvm_sequence and direction in rvm_sequence and index < len(rvm_sequence[direction]):
            mask = rvm_sequence[direction][index]
        elif USE_BIREFNET:
            from . import analyze

            matte = analyze.birefnet_matte(cells[direction][index])
            if matte is not None:
                mask = np.asarray(matte)
        if mask is None:
            mask = (mask_of(cells[direction][index]).astype(np.uint8)) * 255
        alpha_cache[(direction, index)] = mask
        return mask

    def mask_at(direction: str, index: int) -> np.ndarray:
        return alpha_at(direction, index) > 127

    if USE_BIREFNET and not (rvm_sequence or False):
        log("BiRefNet 逐帧抠像：按需计算")

    bodies = [anchor(mask_at(d, min(ref, len(cells[d]) - 1)))[2] for d in DIRECTIONS]
    bodies = [b for b in bodies if b]
    base_body = float(np.median(bodies)) if bodies else 160.0
    scale = float(sprite_cfg["scale"]) if sprite_cfg.get("scale") else char_h / base_body
    log(f"scale {scale:.4f} (ref body {base_body:.0f}px -> {char_h:.0f}px)")

    if sequential:
        picks = list(range(min(count, available)))
        period = picks[-1] - picks[0] + 1 if picks else 0
    else:
        if sprite_cfg.get("period"):
            period = int(sprite_cfg["period"])
        else:
            period = detect_period(cells[DIRECTIONS[0]], ref, count, canvas, char_h, foot_y)
        picks_cfg = sprite_cfg.get("picks")
        picks = ([int(v) for v in picks_cfg][:count] if picks_cfg
                 else [ref + int(round(i * period / count)) for i in range(count)])
    log(f"period {period} frames, picks {picks}")

    result: dict[str, list[str]] = {}
    for d in DIRECTIONS:
        cfg = (sprite_cfg.get("directions") or {}).get(d, {})
        if cfg.get("enabled", True) is False:
            continue
        dx = float(cfg.get("dx", 0) or 0)
        dy = float(cfg.get("dy", 0) or 0)
        folder = out_root / "sprites" / d
        folder.mkdir(parents=True, exist_ok=True)
        reference = anchor(mask_at(d, min(ref, len(cells[d]) - 1)))[:2]
        paths = []
        for i, idx in enumerate(picks):
            idx = max(0, min(len(cells[d]) - 1, idx))
            img = render(cells[d][idx], scale, canvas, (reference[0], reference[1]),
                         canvas[0] / 2, foot_y, offset_x=dx, offset_y=dy, pin_ground=True,
                         alpha=alpha_at(d, idx))
            target = folder / f"frame_{i:02d}.png"
            img.save(target)
            paths.append(str(target.relative_to(out_root)))
        result[d] = paths

    rows = len(result)
    sheet = Image.new("RGB", (canvas[0] * count, canvas[1] * max(1, rows)), BG)
    for row, d in enumerate([d for d in DIRECTIONS if d in result]):
        for i in range(count):
            if i >= len(result[d]):
                continue
            img = Image.open(out_root / result[d][i]).convert("RGBA")
            sheet.paste(img, (canvas[0] * i, canvas[1] * row), img)
    sheet.save(out_root / "contact_sheet.png")
    payload = {"picks": picks, "period": period, "scale": round(scale, 6),
               "canvas": list(canvas), "char_height": char_h, "foot_y": foot_y,
               "sequential": sequential, "frames": result}
    if extra:
        payload.update(extra)          # prompts / run id / model that produced these frames
    (out_root / "sprites.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return result
