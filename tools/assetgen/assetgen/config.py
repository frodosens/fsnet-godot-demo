"""Config, history and artifact bookkeeping for the asset pipeline.

One JSON file per character is the single source of truth. Every run of a step
is kept in ``history/<step>/<run_id>/`` and never overwritten; the config only
records which run is currently selected.
"""
from __future__ import annotations

import json
import re
import time
from pathlib import Path

SCHEMA = 1
STEPS = ["concept", "portrait", "idle", "walk"]
STEP_TITLES = {
    "concept": "1 · 原画",
    "portrait": "2 · 头像",
    "idle": "3 · 四方向待机",
    "walk": "4 · 四方向移动",
}
DIRECTIONS = ["front_left", "front_right", "back_left", "back_right"]

# No background colour here: the key colour lives in config["background"] and is
# appended per step, so the two can never disagree.
DEFAULT_STYLE = (
    "pixel art game sprite, 3/4 view, warm fantasy palette, "
    "flat plain single-colour background, no text, no frame, no watermark"
)
# Phrases an older default baked into every character; they fight chroma keying.
LEGACY_STYLE_TOKENS = ("clean 1px outline, ", "clean 1px outline")
# No prompt may ask for an outline: a dark rim is exactly what a key erases.
OUTLINE_WORDS = ("outline", "描边", "轮廓线", "外框线", "勾边")


def strip_outline(text: str) -> str:
    """Drop every clause that asks for an outline, keep the rest verbatim."""
    if not text:
        return text
    pieces = re.split(r"(?<=[，。；、,;.\n])", text)
    kept = [piece for piece in pieces
            if not any(word in piece.lower() for word in OUTLINE_WORDS)]
    cleaned = "".join(kept).strip()
    return cleaned or text
LEGACY_BG_TOKENS = ("#2b3a3a", "#364242", "#364041")


def now_stamp() -> str:
    return time.strftime("%Y%m%d-%H%M%S")


def run_id(prefix: str = "") -> str:
    stamp = time.strftime("%Y%m%d-%H%M%S")
    ms = int(time.time() * 1000) % 1000
    return f"{prefix}{stamp}-{ms:03d}" if prefix else f"{stamp}-{ms:03d}"


def default_provider() -> dict:
    return {
        "kind": "ark",
        "image_model": "doubao-seedream-5-0-flash-260915",
        "video_model": "doubao-seedance-2-5-260628",
        "vision_model": "doubao-seed-2-1-lite-260915",
        "prompt_model": "",
        "resolution": "480p",
        "duration": 5,
        "ratio": "auto",
    }


def default_sprite_cfg(frames: int) -> dict:
    return {
        "canvas": [128, 128],
        "char_height": 98,
        "foot_y": 119,
        "frames": frames,
        "scale": None,
        "period": None,
        "picks": None,
        "matte": "learned",
        "directions": {d: {"dx": 0, "dy": 0, "enabled": True} for d in DIRECTIONS},
    }


def new_config(character_id: str, description: str, display_name: str = "") -> dict:
    return {
        "schema": SCHEMA,
        "character": {
            "id": character_id,
            "display_name": display_name or character_id,
            "description": description,
            "style": DEFAULT_STYLE,
        },
        "background": "auto",
        "matte": {"method": "auto", "tolerance": 30, "shadow": False},
        "provider": default_provider(),
        "steps": {s: {"status": "pending", "current": None, "history": [],
                      "reference": None, "model": ""} for s in STEPS},
        "sprites": {"idle": default_sprite_cfg(4), "walk": default_sprite_cfg(8)},
    }


class ConfigError(RuntimeError):
    """The config file is missing, empty or not valid JSON."""


def load(path: str | Path) -> dict:
    file = Path(path)
    try:
        raw = file.read_text(encoding="utf-8")
    except OSError as exc:
        raise ConfigError(f"读不到配置文件：{file}（{exc}）") from exc
    if not raw.strip():
        raise ConfigError(
            f"配置文件是空的：{file}\n"
            "可能上次创建时中断了。删掉它再运行一次启动器即可重建，"
            "或手动执行：python -m assetgen.cli new --id <名字> --desc \"描述\" --out \"<路径>\""
        )
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ConfigError(
            f"配置文件不是合法 JSON：{file}\n第 {exc.lineno} 行第 {exc.colno} 列：{exc.msg}"
        ) from exc
    data.setdefault("schema", SCHEMA)
    data.setdefault("background", "auto")
    data.setdefault("matte", {"method": "auto", "tolerance": 30, "shadow": False})
    for step in STEPS:
        data["steps"].setdefault(step, {"status": "pending", "current": None, "history": []})
        data["steps"][step].setdefault("reference", None)
        data["steps"][step].setdefault("model", "")
        data["steps"][step].setdefault("status", "pending")
        data["steps"][step].setdefault("history", [])
    for name in ("idle", "walk"):
        data.setdefault("sprites", {}).setdefault(name, default_sprite_cfg(4 if name == "idle" else 8))
    data["character"]["style"] = strip_outline(data.get("character", {}).get("style", ""))
    for key, value in (data.get("prompts") or {}).items():
        if isinstance(value, str):
            data["prompts"][key] = strip_outline(value)
    style = data.get("character", {}).get("style", "")
    for token in LEGACY_BG_TOKENS:
        if token in style:          # old configs baked the backdrop colour into the style
            style = style.replace(token, data["background"])
    for token in LEGACY_STYLE_TOKENS:
        if token in style:          # the outline requirement ate dark edges on keying
            style = style.replace(token, "")
    if style:
        data["character"]["style"] = style
    # prompts were generated from the old style; keep them consistent
    for key, value in (data.get("prompts") or {}).items():
        if not isinstance(value, str):
            continue
        cleaned = value
        for token in LEGACY_STYLE_TOKENS:
            cleaned = cleaned.replace(token, "")
        if cleaned != value:
            data["prompts"][key] = cleaned
    return data


def save(cfg: dict, path: str | Path) -> None:
    # never persist an outline requirement, however it got typed in
    if isinstance(cfg.get("character"), dict):
        cfg["character"]["style"] = strip_outline(cfg["character"].get("style", ""))
    for key, value in (cfg.get("prompts") or {}).items():
        if isinstance(value, str):
            cfg["prompts"][key] = strip_outline(value)
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def project_dir(config_path: str | Path) -> Path:
    return Path(config_path).resolve().parent


def record(cfg: dict, config_path: str | Path, step: str, run: str, files: dict,
           prompt: str = "", params: dict | None = None, note: str = "",
           prompts: dict | None = None) -> dict:
    """Append a run to the step history and make it current.

    ``prompts`` holds every prompt that was actually sent for this run, verbatim,
    keyed by prompt slot (concept / portrait / grid / idle_video / walk_video).
    The config therefore always documents what produced each artifact, even after
    the editable prompt has been changed again.
    """
    entry = {
        "run": run,
        "created": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "prompt": prompt,
        "prompts": prompts or {},
        "params": params or {},
        "files": files,
        "note": note,
    }
    state = cfg["steps"][step]
    state["history"].append(entry)
    state["current"] = entry["run"]
    state["status"] = "done"
    save(cfg, config_path)
    return entry


def current_entry(cfg: dict, step: str) -> dict | None:
    state = cfg["steps"][step]
    if not state.get("current"):
        return None
    for entry in state["history"]:
        if entry["run"] == state["current"]:
            return entry
    return None


def select(cfg: dict, config_path: str | Path, step: str, run: str) -> dict | None:
    state = cfg["steps"][step]
    for entry in state["history"]:
        if entry["run"] == run:
            state["current"] = run
            state["status"] = "done"
            save(cfg, config_path)
            return entry
    return None


def resolve_reference(config_path: str | Path, rel: str | None) -> Path | None:
    """A reference may live next to the character or in the project root."""
    if not rel:
        return None
    candidate = Path(rel)
    if candidate.is_absolute():
        return candidate if candidate.exists() else None
    here = Path(config_path).resolve().parent
    for base in (here, here.parent):
        path = base / candidate
        if path.exists():
            return path
    return None


def artifact_path(config_path: str | Path, cfg: dict, step: str, key: str) -> Path | None:
    entry = current_entry(cfg, step)
    if not entry:
        return None
    rel = entry["files"].get(key)
    if not rel:
        return None
    return project_dir(config_path) / rel


def next_pending(cfg: dict) -> str | None:
    for step in STEPS:
        if cfg["steps"][step]["status"] != "done":
            return step
    return None

