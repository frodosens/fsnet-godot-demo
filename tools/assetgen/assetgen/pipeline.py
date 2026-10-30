"""Step execution: concept -> portrait -> idle -> walk.

A step only ever appends to history; the config records which run is current.
Every prompt lives in ``cfg["prompts"]`` so the GUI can edit it, and the
pipeline always reads it from there (never from the templates directly).
"""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw

from . import analyze, ark, config, sprites, templates

PROMPT_KEYS = ["concept", "portrait", "grid", "idle_video", "walk_video"]

# Which prompt of the NEXT step is rewritten from which artifact of THIS step.
REFINE_NEXT = {
    "concept": [("portrait", "image", "原画"), ("grid", "image", "原画")],
}


def _refine_targets(cfg: dict, step: str):
    if step == "idle":
        return [("walk_video", "contact_sheet", "四方向待机精灵表")]
    return REFINE_NEXT.get(step, [])


def default_prompts(c: dict) -> dict:
    return {key: templates.BUILDERS[key](c) for key in PROMPT_KEYS}


def ensure_prompts(cfg: dict) -> dict:
    prompts = cfg.setdefault("prompts", {})
    for key, value in default_prompts(cfg["character"]).items():
        prompts.setdefault(key, value)
    return prompts


# Sentences the rewrite must never lose: they are the layout contract with the model.
REQUIRED = {
    "concept": [templates.BG_HEX],
    "portrait": ["头像", templates.BG_HEX],
    "grid": ["2 行 2 列"],
    "idle_video": ["2 行 2 列"],
    "walk_video": ["2 行 2 列"],
}


def _keeps_structure(key: str, text: str) -> bool:
    return all(marker in text for marker in REQUIRED.get(key, []))


def _refine_instruction(label: str, current: str) -> str:
    return (
        f"这张图是刚生成的角色素材（{label}）。下面是一段「下一步」要用的提示词：\n\n"
        f"---\n{current}\n---\n\n"
        "请把它改写成与这张图完全一致的版本，但**只允许修改外观**：角色配色、服装、装备、头身比、背景色。"
        "严禁修改任何结构性内容：图片里有几个格子、几行几列、每格朝向的顺序、动作描述、"
        "以及提示词里的占位符（如 {frames} {direction} {pose}）都必须原样保留。"
        "如果图里是拼好的多格精灵表，不要照着它的行列数去改提示词里的格子数。"
        "直接输出改写后的完整提示词，不要解释、不要加引号、不要分点。"
    )


def refine_next(cfg: dict, config_path: Path, step: str, log=print,
                use_vision: bool = True) -> dict:
    """Rewrite the next step's prompt from this step's artifact, using vision.

    Failure is never fatal: the previous prompt is kept and the reason is logged.
    """
    targets = _refine_targets(cfg, step)
    if not targets:
        return {}
    entry = config.current_entry(cfg, step)
    if not entry:
        return {}
    model = cfg["provider"].get("vision_model")
    changed: dict[str, str] = {}
    for key, file_key, label in targets:
        rel = entry["files"].get(file_key)
        if not rel:
            continue
        image = config.project_dir(config_path) / rel
        if not image.exists():
            continue
        current = prompt_for(cfg, key)
        text = ""
        source = f"auto:{step}"
        try:
            if not use_vision:
                raise RuntimeError("offline mode")
            text = ark.describe_image(model, _refine_instruction(label, current), image, log=log)
            text = text.strip().strip('"').strip()
            if len(text) < 40:
                text = ""
        except Exception as exc:  # no vision model -> fall back to measurement
            log(f"  vision refine unavailable ({type(exc).__name__}); measuring the artifact instead")
        if text and not _keeps_structure(key, text):
            log(f"  rewrite of {key} dropped the layout contract; keeping the measured version instead")
            text = ""
        if not text:
            text = analyze.apply(current, image)
            source = f"measured:{step}"
            log(f"  measured {key} from {label}: " + analyze.describe(image)[len(analyze.MARKER):][:80])
        cfg.setdefault("prompts", {})[key] = text
        cfg.setdefault("prompt_sources", {})[key] = source
        changed[key] = text
        log(f"  refined {key} from {step} artifact ({len(text)} chars, source={source})")
    if changed:
        config.save(cfg, config_path)
    return changed


STYLE_SHIFTS = [
    "轮廓保持 1 像素硬边，阴影用两段色阶，高光只点在金属边缘",
    "配色压低饱和度，主光源来自左上，地面留一圈更暗的接触阴影",
    "布料褶皱用三档明度概括，金属反光集中在受光面，避免大面积纯白",
    "整体对比提高一档，暗部偏冷、亮部偏暖，保持像素颗粒一致",
    "轮廓外侧留 1 像素透明呼吸位，内部结构用硬边色块分层",
]


def _local_variant(current: str, character: dict) -> str:
    """Structural content stays, wording and rendering notes are refreshed."""
    import hashlib
    import time

    seed = int(hashlib.sha1((current + str(time.time())).encode()).hexdigest(), 16)
    shift = STYLE_SHIFTS[seed % len(STYLE_SHIFTS)]
    base = current.split("\n")[0].strip()
    return (
        f"{base}\n"
        f"渲染要求：{shift}；配色与头身比沿用上一步产物；背景保持纯深灰绿色，不加文字与边框。"
    )


STEP_PROMPT_KEY = {"concept": "concept", "portrait": "portrait",
                   "idle": "idle_video", "walk": "walk_video"}


def _reference_instruction(current: str) -> str:
    return (
        "这张图是风格与比例参考，不是要生成的角色本身。\n"
        "请分析它的画风（像素密度、明暗层次、配色倾向、背景色）和角色在画面中的占比，"
        "然后把下面这段提示词改写成符合该风格的版本：\n\n---\n" + current + "\n---\n\n"
        "硬性要求：只改画风、质感、配色、比例的描述；**不要写任何描边、轮廓线、勾边的要求**；"
        "不得改动结构——格子数量、几行几列、"
        "每格朝向顺序、动作描述、以及 {direction} {frames} {pose} 这类占位符必须原样保留。\n"
        "直接输出改写后的完整提示词，不要解释、不要分点、不要加引号。"
    )


def calibrate_from_reference(cfg: dict, config_path: Path, step: str, image: Path, log=print) -> dict:
    """Reverse-engineer style from a reference image and fold it into the prompt."""
    sync_background(cfg)
    key = STEP_PROMPT_KEY[step]
    current = prompt_for(cfg, key)
    measured = analyze.measure(image)
    ratio = measured["body_height_px"] / max(1, measured["canvas"][1])
    log(f"  参考图 {measured['canvas'][0]}x{measured['canvas'][1]}，角色占高 {ratio:.2f}，"
        f"背景 {measured['background']}")

    text = ""
    try:
        model = cfg["provider"].get("vision_model")
        text = ark.describe_image(model, _reference_instruction(current), image, log=log).strip().strip('"')
        if text and not _keeps_structure(key, text):
            log("  改写结果丢了结构约束，退回测量版")
            text = ""
    except Exception as exc:
        log(f"  视觉模型不可用（{type(exc).__name__}），改用像素测量修正")
    if not text:
        text = analyze.apply(current, image)
        cfg.setdefault("prompt_sources", {})[key] = f"measured:reference"
    else:
        cfg.setdefault("prompt_sources", {})[key] = "reference"
    cfg.setdefault("prompts", {})[key] = text

    result = {"prompt": text, "ratio": round(ratio, 4), "background": measured["background"],
              "palette": measured["palette"]}
    if step in ("idle", "walk"):
        sprite_cfg = cfg["sprites"][step]
        canvas_h = int((sprite_cfg.get("canvas") or [128, 128])[1])
        suggested = max(40, min(canvas_h - 12, round(ratio * canvas_h)))
        sprite_cfg["char_height"] = suggested
        result["char_height"] = suggested
        log(f"  角色高按参考比例标定为 {suggested}px（画布 {canvas_h}px）")
    config.save(cfg, config_path)
    return result


def regenerate_prompt(cfg: dict, config_path: Path, key: str, log=print) -> tuple[str, str]:
    """Write a fresh prompt for one slot. Returns (text, source)."""
    current = prompt_for(cfg, key)
    label = {"concept": "原画", "portrait": "头像", "grid": "四方向拼图",
             "idle_video": "四方向待机视频", "walk_video": "四方向移动视频"}.get(key, key)
    character = cfg["character"]
    instruction = (
        "你在为一个像素风战棋游戏写素材生成提示词。\n"
        f"角色设定：{character['description']}\n美术风格：{character['style']}\n"
        f"这一步要生成的是：{label}\n\n"
        "下面是一条现有提示词：\n---\n" + current + "\n---\n\n"
        "请重写它：必须保留所有结构性约束（2 行 2 列共 4 个格子、左上/右上/左下/右下各自的朝向、"
        "原地动作、不越界不重叠不跨格、像素风与首帧一致）；只重写外观描述、动作细节与措辞，"
        "让它更具体、更容易被图像模型执行。直接输出新的完整提示词，不要解释、不要分点、不要加引号。"
    )
    model = cfg["provider"].get("prompt_model") or cfg["provider"].get("vision_model")
    try:
        text = ark.chat_text(model, instruction, log=log).strip().strip('"').strip()
        if len(text) >= 40:
            cfg.setdefault("prompts", {})[key] = text
            cfg.setdefault("prompt_sources", {})[key] = f"generated:{model}"
            config.save(cfg, config_path)
            log(f"  模型返回 {len(text)} 字，已写入 {key}")
            return text, f"generated:{model}"
        log("  模型返回内容过短，改用本地变体")
    except Exception as exc:
        log(f"  提示词模型不可用（{type(exc).__name__}: {exc}），改用本地变体")
    text = _local_variant(current, character)
    cfg.setdefault("prompts", {})[key] = text
    cfg.setdefault("prompt_sources", {})[key] = "local-variant"
    config.save(cfg, config_path)
    log(f"  已生成本地变体 {len(text)} 字")
    return text, "local-variant"


def prompt_for(cfg: dict, key: str) -> str:
    ensure_prompts(cfg)
    return cfg["prompts"].get(key) or templates.BUILDERS[key](cfg["character"])


IMAGE_STEPS = ("concept", "portrait")


def model_for(cfg: dict, step: str) -> str:
    """Per-step override, else the kind default."""
    override = (cfg["steps"].get(step) or {}).get("model") or ""
    if override:
        return override
    return cfg["provider"]["image_model" if step in IMAGE_STEPS else "video_model"]


def default_model_for(cfg: dict, step: str) -> str:
    return cfg["provider"]["image_model" if step in IMAGE_STEPS else "video_model"]


class Provider:
    def image(self, prompt: str, target: Path, size: str = "1024x1024",
              reference: Path | None = None, log=print, model: str = "") -> Path:
        raise NotImplementedError

    def video(self, prompt: str, target: Path, first_frame: Path, log=print,
              model: str = "") -> dict:
        raise NotImplementedError


class ArkProvider(Provider):
    def __init__(self, cfg: dict):
        self.cfg = cfg
        self.p = cfg["provider"]

    def image(self, prompt, target, size="1024x1024", reference=None, log=print, model=""):
        return ark.generate_image(model or self.p["image_model"], prompt, target, size=size,
                                  reference=reference, log=log)

    def video(self, prompt, target, first_frame, log=print, model=""):
        return ark.generate_video(model or self.p["video_model"], prompt, target,
                                  first_frame=first_frame,
                                  duration=int(self.p.get("duration", 5)),
                                  resolution=self.p.get("resolution", "480p"),
                                  ratio=self.p.get("ratio", "auto"), log=log)


class DryProvider(Provider):
    """Offline provider: renders placeholder art and a synthetic 2x2 clip.

    The point is to exercise the whole pipeline (files, history, sprite export,
    GUI wiring) without spending credits. The synthetic clip deliberately bobs
    the body vertically so the ground pinning has something to correct.
    """

    CELL = 320

    def __init__(self, cfg: dict):
        self.cfg = cfg

    def image(self, prompt, target, size="1024x1024", reference=None, log=print, model=""):
        w, h = (int(v) for v in size.lower().split("x"))
        img = Image.new("RGB", (w, h), sprites.BG)
        d = ImageDraw.Draw(img)
        d.rectangle([8, 8, w - 8, h - 8], outline=(70, 90, 90))
        self._figure(d, w // 2, int(h * 0.62), int(h * 0.30), facing=1, tint=(196, 112, 92))
        text = prompt[:120].replace("\n", " ")
        d.multiline_text((16, h - 70), "DRY RUN\n" + text, fill=(210, 220, 210))
        target.parent.mkdir(parents=True, exist_ok=True)
        img.save(target)
        log(f"dry image -> {target.name}")
        return target

    @staticmethod
    def _figure(d: ImageDraw.ImageDraw, cx: int, foot: int, height: int, facing: int = 1,
                tint=(200, 140, 110), leg_phase: float = 0.0, shield=True):
        head = max(6, height // 5)
        body_h = height - head
        top = foot - height
        d.ellipse([cx - head // 2, top, cx + head // 2, top + head], fill=(228, 190, 160))
        d.rectangle([cx - head // 3, top + head, cx + head // 3, top + head + body_h // 2],
                    fill=tint)
        swing = int(body_h * 0.28 * leg_phase)
        d.line([(cx - 4, top + head + body_h // 2), (cx - 4 - swing, foot)], fill=(70, 60, 50), width=6)
        d.line([(cx + 4, top + head + body_h // 2), (cx + 4 + swing, foot)], fill=(70, 60, 50), width=6)
        if shield:
            sx_a = cx + facing * (head // 2 + 4)
            sx_b = cx + facing * (head // 2 + 26)
            d.ellipse([min(sx_a, sx_b), top + head + 6,
                       max(sx_a, sx_b), top + head + 34], fill=(150, 160, 170))

    def video(self, prompt, target, first_frame, log=print, model=""):
        frames_dir = target.parent / "dry_frames"
        frames_dir.mkdir(parents=True, exist_ok=True)
        size = 640
        total = 121
        for i in range(total):
            phase = (i % 24) / 24.0
            bob = int(12 * abs(phase - 0.5) * 2)          # deliberately unstable
            img = Image.new("RGB", (size, size), sprites.BG)
            d = ImageDraw.Draw(img)
            for cell in range(4):
                row, col = divmod(cell, 2)
                cx = col * self.CELL + self.CELL // 2
                foot = row * self.CELL + self.CELL - 40 + bob
                d.line([(col * self.CELL + 40, row * self.CELL + self.CELL - 40),
                        (col * self.CELL + self.CELL - 40, row * self.CELL + self.CELL - 40)],
                       fill=(36, 48, 48), width=2)
                self._figure(d, cx, foot, int(self.CELL * 0.55), facing=1 if col == 0 else -1,
                             leg_phase=1.0 if (i // 3) % 2 else -1.0)
            img.save(frames_dir / f"f{i:03d}.png")
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-framerate", "24", "-i",
                        str(frames_dir / "f%03d.png"), "-c:v", "libx264",
                        "-pix_fmt", "yuv420p", "-crf", "20", str(target)], check=True)
        shutil.rmtree(frames_dir, ignore_errors=True)
        log(f"dry video -> {target.name}")
        return {"id": "dry", "status": "succeeded", "usage": {"total_tokens": 0}}


def make_provider(cfg: dict, dry: bool = False) -> Provider:
    return DryProvider(cfg) if dry else ArkProvider(cfg)


def _run_dir(config_path: Path, step: str) -> Path:
    return config.project_dir(config_path) / step / config.run_id()


def matting_method(cfg: dict) -> str:
    """auto = learned matting when the model is present, colour key otherwise."""
    return (cfg.get("matte") or {}).get("method") or "auto"


def matting_options(cfg: dict) -> dict:
    matte = cfg.get("matte") or {}
    return {"method": matte.get("method") or "auto",
            "tolerance": int(matte.get("tolerance") or 30),
            "shadow": bool(matte.get("shadow")),
            "shadow_band": float(matte.get("shadow_band") or 0.18)}


def _opaque_artifact(config_path: Path, cfg: dict, step: str) -> Path | None:
    """Prefer the raw (opaque) file as a reference image; alpha would leak through."""
    raw = config.artifact_path(config_path, cfg, step, "raw")
    if raw and Path(raw).exists():
        return Path(raw)
    return config.artifact_path(config_path, cfg, step, "image")


def _clean_background(raw: Path, finished: Path, log=print, tolerance: int = 30,
                      method: str = "auto", shadow: bool = False,
                      shadow_band: float = 0.18) -> dict:
    report = analyze.remove_background(raw, finished, tolerance=tolerance,
                                       expected=templates.BG_HEX, method=method,
                                       shadow=shadow, shadow_band=shadow_band)
    extra = f"，去投影 {report['shadow_px']} 像素" if report.get("shadow_px") else ""
    log(f"  去底[{report.get('method')}]：保留 {report['kept_ratio'] * 100:.0f}% 像素，"
        f"实测背景 {report['background']}，输出 {report['size'][0]}x{report['size'][1]}{extra}")
    if not report.get("matches_expected", True):
        log(f"  注意：背景与提示词要求的 {templates.BG_HEX} 不一致，去底可能有残留")
    if report["suspicious"]:
        log("  注意：去底比例异常，背景可能不是纯色，请检查成品")
    return report


def _rel(config_path: Path, path: Path) -> str:
    return str(Path(path).resolve().relative_to(config.project_dir(config_path).resolve()))


def split_strip(image, rows: int, cols: int, inset: float = 0.02):
    """Cut a rows x cols action sheet into cells, row-major.

    ``inset`` trims a small margin so the separator lines the model likes to
    draw never end up inside a cell (they would confuse the foot anchor).
    """
    w, h = image.size
    cw, ch = w / cols, h / rows
    mx, my = int(cw * inset), int(ch * inset)
    cells = []
    for r in range(rows):
        for c in range(cols):
            left, top = int(c * cw), int(r * ch)
            cells.append(image.crop((left + mx, top + my, int((c + 1) * cw) - mx, int((r + 1) * ch) - my)))
    return cells


FLAT_BACKGROUND_STEPS = ("concept", "portrait")


def with_flat_background(text: str, step: str) -> str:
    """The keyer needs a declared flat colour; never let a rewrite drop it."""
    if step not in FLAT_BACKGROUND_STEPS:
        return text
    if templates.BG_HEX in text and "纯色" in text:
        return text
    return text.rstrip() + "\n" + templates.BACKGROUND_CLAUSE


def with_style(text: str, style: str) -> str:
    style = (style or "").strip()
    if not style or style in text:
        return text
    return text.rstrip() + "\n风格要求：" + style


def sync_background(cfg: dict) -> str:
    """Every prompt and every key operation must agree on one colour."""
    hex_value = (cfg.get("background") or "auto").strip()
    if hex_value.lower() in templates.AUTO_BACKGROUND:
        hex_value = ""
    templates.set_background(hex_value)
    return hex_value


def _adopt_measured_background(cfg: dict, config_path: Path, report: dict, log=print) -> None:
    """In auto mode the colour is whatever the model actually painted."""
    current = (cfg.get("background") or "auto").strip()
    if current.lower() not in templates.AUTO_BACKGROUND:
        return
    measured = report.get("background") or ""
    if not measured or not measured.startswith("#"):
        return
    cfg["background"] = measured
    templates.set_background(measured)
    config.save(cfg, config_path)
    log(f"  背景色自动定为 {measured}，后续步骤沿用")


def run(cfg: dict, config_path: Path, step: str, provider: Provider, log=print,
        refine: bool = True, style: str = "") -> dict:
    sync_background(cfg)
    """Execute one step end to end and record it in history."""
    ensure_prompts(cfg)
    cfg["sprites"].setdefault(step, config.default_sprite_cfg(4 if step == "idle" else 8))
    out = _run_dir(config_path, step)
    out.mkdir(parents=True, exist_ok=True)
    files: dict[str, str] = {}
    used: dict[str, str] = {}
    note = ""

    if step == "concept":
        used["concept"] = with_flat_background(with_style(prompt_for(cfg, "concept"), style), step)
        raw = out / "concept_raw.png"
        # concept and portrait seed each other: whichever exists is the reference
        ref = _opaque_artifact(config_path, cfg, "portrait")
        if ref is not None:
            log(f"  用已生成的头像作为原画参考：{ref.name}")
        provider.image(used["concept"], raw, size="1024x1024", reference=ref, log=log,
                       model=model_for(cfg, step))
        finished = out / "concept.png"
        report = _clean_background(raw, finished, log=log, **matting_options(cfg))
        _adopt_measured_background(cfg, config_path, report, log=log)
        files["image"] = _rel(config_path, finished)
        files["raw"] = _rel(config_path, raw)

    elif step == "portrait":
        used["portrait"] = with_flat_background(with_style(prompt_for(cfg, "portrait"), style), step)
        ref = _opaque_artifact(config_path, cfg, "concept")
        if ref is not None:
            log(f"  用已生成的原画作为头像参考：{ref.name}")
        raw = out / "portrait_raw.png"
        provider.image(used["portrait"], raw, size="1024x1024", reference=ref, log=log,
                       model=model_for(cfg, step))
        finished = out / "portrait.png"
        report = _clean_background(raw, finished, log=log, **matting_options(cfg))
        _adopt_measured_background(cfg, config_path, report, log=log)
        files["image"] = _rel(config_path, finished)
        files["raw"] = _rel(config_path, raw)

    elif step in ("idle", "walk"):
        grid = config.artifact_path(config_path, cfg, "idle", "grid")
        if grid is None or not Path(grid).exists():
            used["grid"] = with_style(prompt_for(cfg, "grid"), style)
            ref = _opaque_artifact(config_path, cfg, "concept")
            grid = out / "grid.png"
            provider.image(used["grid"], grid, size="1024x1024", reference=ref, log=log,
                           model=model_for(cfg, "concept"))
        files["grid"] = _rel(config_path, Path(grid))

        key = f"{step}_video"
        used[key] = with_style(prompt_for(cfg, key), style)
        video = out / f"{step}.mp4"
        provider.video(used[key], video, Path(grid), log=log, model=model_for(cfg, step))
        files["video"] = _rel(config_path, video)
        sprites.USE_LEARNED_MATTE = bool(
            (cfg["sprites"][step].get("matte") or "").lower() in ("learned", "net"))
        exported = sprites.export(video, cfg["sprites"][step], out, log=log,
                                  extra={"run": out.name, "step": step,
                                         "prompts": dict(used), "provider": dict(cfg["provider"])})
        for d, paths in exported.items():
            files[f"sprites/{d}"] = _rel(config_path, out / Path(paths[0])).rsplit("/", 1)[0]
        files["contact_sheet"] = _rel(config_path, out / "contact_sheet.png")
        note = f"{len(exported)} directions x {cfg['sprites'][step].get('frames')} frames"
    else:
        raise ValueError(f"unknown step {step!r}")

    entry = config.record(cfg, config_path, step, out.name, files,
                          prompt=next(iter(used.values()), ""),
                          prompts=used,
                          params={"provider": dict(cfg["provider"]),
                                  "model": model_for(cfg, step)},
                          note=note)
    log(f"{step}: {out.name} done")
    if refine:
        refine_next(cfg, config_path, step, log=log,
                    use_vision=not isinstance(provider, DryProvider))
    return entry


def clean_step(cfg: dict, config_path: Path, step: str, log=print,
               tolerance: int = 30, method: str = "auto",
               shadow: bool | None = None) -> dict:
    """Re-run background removal for a finished concept/portrait."""
    if step not in ("concept", "portrait"):
        raise ValueError("only concept and portrait have a flat backdrop to remove")
    sync_background(cfg)
    entry = config.current_entry(cfg, step)
    if not entry:
        raise RuntimeError(f"{step} 还没有生成过")
    project_root = config.project_dir(config_path)
    raw_rel = entry["files"].get("raw")
    if raw_rel:
        raw = project_root / raw_rel
    else:
        # legacy entry: keep a copy of the only file we have before keying it
        source = project_root / entry["files"]["image"]
        if not source.exists():
            raise RuntimeError(f"找不到原始文件 {source}")
        raw = source.with_name(f"{step}_raw.png")
        if not raw.exists():
            raw.write_bytes(source.read_bytes())
    if not raw.exists():
        raise RuntimeError(f"找不到原始文件 {raw}")
    finished = raw.with_name(f"{step}.png")
    matte = cfg.get("matte") or {}
    report = _clean_background(raw, finished, log=log, tolerance=tolerance, method=method,
                               shadow=bool(matte.get("shadow")) if shadow is None else shadow,
                               shadow_band=float(matte.get("shadow_band") or 0.18))
    entry["files"]["image"] = str(finished.relative_to(config.project_dir(config_path)))
    entry["files"].setdefault("raw", str(raw.relative_to(config.project_dir(config_path))))
    config.save(cfg, config_path)
    return report


def export_only(cfg: dict, config_path: Path, step: str, log=print) -> dict:
    """Re-export sprites from the already generated clip or strip images."""
    if step not in ("idle", "walk"):
        raise ValueError("only idle/walk have sprites")
    entry = config.current_entry(cfg, step)
    if not entry:
        raise RuntimeError(f"{step} has not been generated yet")
    sprite_cfg = cfg["sprites"][step]
    frames = int(sprite_cfg.get("frames") or 4)
    out = None
    if "video" in entry["files"]:
        video = config.project_dir(config_path) / entry["files"]["video"]
        out = video.parent
        exported = sprites.export(video, sprite_cfg, out, log=log,
                                  extra={"run": entry["run"], "step": step,
                                         "prompts": dict(entry.get("prompts") or {}),
                                         "provider": dict(cfg["provider"])})
    elif any(key.startswith("strip/") for key in entry["files"]):
        cols = min(4, frames)
        rows = (frames + cols - 1) // cols
        cells = {}
        for direction in sprites.DIRECTIONS:
            rel = entry["files"].get(f"strip/{direction}")
            if not rel:
                continue
            path = config.project_dir(config_path) / rel
            out = path.parent
            cells[direction] = split_strip(Image.open(path).convert("RGB"), rows, cols)[:frames]
        exported = sprites.export_cells(cells, sprite_cfg, out, log=log, sequential=True)
    else:
        raise RuntimeError(f"{step} has no source to re-export")
    files = dict(entry["files"])
    for d, paths in exported.items():
        files[f"sprites/{d}"] = _rel(config_path, out / Path(paths[0])).rsplit("/", 1)[0]
    files["contact_sheet"] = _rel(config_path, out / "contact_sheet.png")
    entry["files"] = files
    config.save(cfg, config_path)
    log(f"{step}: re-exported with current settings")
    return entry


def status(cfg: dict) -> dict:
    out = {}
    for step in config.STEPS:
        state = cfg["steps"][step]
        out[step] = {"status": state.get("status", "pending"),
                     "current": state.get("current"),
                     "runs": len(state.get("history", []))}
    return out
