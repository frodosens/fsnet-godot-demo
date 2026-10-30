"""A work folder is a project: one subfolder per character, plus shared settings.

Layout::

    work/
      project.json          # shared style reference + style prompt
      mara/config.json      # one character
      neri/config.json
"""
from __future__ import annotations

import json
from pathlib import Path

from . import config

PROJECT_FILE = "project.json"
SCHEMA = 1


def project_file(work: str | Path) -> Path:
    return Path(work) / PROJECT_FILE


STYLE_STEPS = ["concept", "portrait", "idle", "walk"]
SECRETS_FILE = ".secrets.json"


def default_settings() -> dict:
    return {
        "schema": SCHEMA,
        "name": "",
        "style_prompt": "",
        "style_reference": "",
        "apply_style_to_new": True,
        "background": "auto",
        "refine": True,
        "api": {
            "base_url": "https://ark.cn-beijing.volces.com/api/v3",
            "key_env": "ARK_API_KEY",
            "image_model": "doubao-seedream-5-0-flash-260915",
            "video_model": "doubao-seedance-2-5-260628",
            "vision_model": "doubao-seed-2-1-lite-260915",
        },
        "step_styles": {step: {"prompt": "", "source": ""} for step in STYLE_STEPS},
    }


def load_settings(work: str | Path) -> dict:
    path = project_file(work)
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            data = {}
    else:
        data = {}
    merged = default_settings()
    merged.update({k: v for k, v in data.items() if k in merged})
    return merged


def save_settings(work: str | Path, settings: dict) -> Path:
    work = Path(work)
    work.mkdir(parents=True, exist_ok=True)
    path = project_file(work)
    payload = default_settings()
    payload.update({k: settings[k] for k in payload if k in settings})
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def secrets_path(work: str | Path) -> Path:
    return Path(work) / SECRETS_FILE


def load_secrets(work: str | Path) -> dict:
    path = secrets_path(work)
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def save_secrets(work: str | Path, values: dict) -> Path:
    path = secrets_path(work)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(values, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def api_settings(work: str | Path) -> dict:
    settings = load_settings(work)
    api = dict(settings.get("api") or {})
    api["api_key"] = load_secrets(work).get("api_key", "")
    return api


def apply_api(work: str | Path) -> dict:
    """Push the project's API settings into the ark client."""
    from . import ark

    api = api_settings(work)
    ark.configure(api.get("base_url", ""), api.get("api_key", ""), api.get("key_env", ""))
    api["key_source"] = ark.key_source()
    return api


def step_style(work: str | Path, step: str) -> str:
    return ((load_settings(work).get("step_styles") or {}).get(step) or {}).get("prompt", "")


def set_step_style(work: str | Path, step: str, prompt: str, source: str = "") -> None:
    settings = load_settings(work)
    settings.setdefault("step_styles", {})[step] = {"prompt": prompt, "source": source}
    save_settings(work, settings)


IMAGE_SUFFIXES = (".png", ".jpg", ".jpeg", ".webp", ".bmp")


def generate_step_style(work: str | Path, step: str, source_file: str | Path, log=print) -> str:
    """Summarise a reference file into a style prompt for one step."""
    from . import ark

    path = Path(source_file)
    api = api_settings(work)
    model = api.get("vision_model") or "doubao-seed-2-1-lite-260915"
    if path.suffix.lower() in IMAGE_SUFFIXES:
        instruction = (
            "总结这张图的画风，写成一段可以直接拼进图像生成提示词的风格描述："
            "像素密度、描边粗细、明暗层次、配色倾向、背景色。120 字以内，"
            "不要分点、不要解释、不要加引号。"
        )
        text = ark.describe_image(model, instruction, path, log=log)
    else:
        raw = path.read_text(encoding="utf-8", errors="replace")[:4000]
        instruction = (
            "下面是一份美术风格说明或需求文档。请把它压缩成一段可以直接拼进图像生成提示词的"
            "风格描述，120 字以内，不要分点、不要解释：\n\n" + raw
        )
        text = ark.chat_text(model, instruction, log=log)
    text = text.strip().strip('"').strip()
    set_step_style(work, step, text, f"file:{path.name}")
    log(f"  {step} 风格提示词已从 {path.name} 生成（{len(text)} 字）")
    return text


def characters(work: str | Path) -> list[dict]:
    """Every subfolder holding a config.json, newest activity first."""
    work = Path(work)
    rows = []
    if not work.is_dir():
        return rows
    for folder in sorted(work.iterdir()):
        if not folder.is_dir():
            continue
        cfg_path = folder / "config.json"
        if not cfg_path.exists():
            continue
        try:
            cfg = config.load(cfg_path)
        except Exception as exc:  # broken config must not hide the rest
            rows.append({"path": cfg_path, "id": folder.name, "name": folder.name,
                         "description": f"(配置读取失败: {type(exc).__name__})",
                         "status": {step: "error" for step in config.STEPS},
                         "updated": "", "error": str(exc)})
            continue
        status = {step: cfg["steps"][step].get("status", "pending") for step in config.STEPS}
        portrait = _thumb(cfg_path, cfg)
        updated = max((cfg["steps"][s].get("history") or [{}])[-1].get("created", "")
                      for s in config.STEPS) if any(status.values()) else ""
        rows.append({
            "path": cfg_path,
            "id": cfg["character"].get("id", folder.name),
            "name": cfg["character"].get("display_name", folder.name),
            "description": cfg["character"].get("description", ""),
            "status": status,
            "updated": updated,
            "portrait": portrait,
        })
    rows.sort(key=lambda r: (r["updated"], r["id"]), reverse=True)
    return rows


def _thumb(config_path: Path, cfg: dict) -> Path | None:
    """Portrait first, concept as fallback - used as the list thumbnail."""
    for step, key in (("portrait", "image"), ("concept", "image")):
        path = config.artifact_path(config_path, cfg, step, key)
        if path and Path(path).exists():
            return Path(path)
    return None


def new_character(work: str | Path, character_id: str, description: str,
                  display_name: str = "") -> Path:
    """Create <work>/<id>/config.json, seeded with the project style."""
    work = Path(work)
    settings = load_settings(work)
    cfg = config.new_config(character_id, description, display_name or character_id)
    cfg["background"] = settings.get("background") or "auto"
    style = cfg["character"]["style"]
    if settings.get("apply_style_to_new") and settings.get("style_prompt"):
        cfg["character"]["style"] = style + " " + settings["style_prompt"].strip()
    reference = settings.get("style_reference") or ""
    if reference:
        for step in config.STEPS:
            cfg["steps"][step]["reference"] = reference
    path = work / character_id / "config.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path
