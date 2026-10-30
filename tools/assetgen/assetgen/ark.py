"""Minimal Volcengine Ark client (stdlib only): images + async video tasks.

Only the two calls the pipeline needs are implemented. Everything is bounded:
one retry on 429/5xx, a hard timeout per request, and a bounded poll loop.
"""
from __future__ import annotations

import base64
import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = "https://ark.cn-beijing.volces.com/api/v3"
ENV_KEY = "ARK_API_KEY"

_BASE = BASE
_KEY_OVERRIDE = ""
_KEY_ENV = ENV_KEY


def configure(base_url: str = "", api_key: str = "", key_env: str = "") -> None:
    """Runtime overrides coming from the project settings.

    An empty api_key means "fall back to the environment variable", so a project
    that never filled the API tab just uses ARK_API_KEY.
    """
    global _BASE, _KEY_OVERRIDE, _KEY_ENV
    _BASE = (base_url or BASE).rstrip("/")
    _KEY_OVERRIDE = api_key or ""
    _KEY_ENV = (key_env or ENV_KEY).strip() or ENV_KEY


def base_url() -> str:
    return _BASE


def _key_names() -> list[str]:
    names = [_KEY_ENV]
    if _KEY_ENV != ENV_KEY:
        names.append(ENV_KEY)
    return names


def _registry(name: str) -> str:
    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as handle:
            return winreg.QueryValueEx(handle, name)[0]
    except (OSError, ImportError):
        return ""


def _lookup() -> tuple[str, str]:
    """(key, where it came from) - project override, env var, then user registry."""
    if _KEY_OVERRIDE:
        return _KEY_OVERRIDE, "项目设置"
    for name in _key_names():
        value = os.environ.get(name)
        if value:
            return value, f"环境变量 {name}"
    for name in _key_names():
        value = _registry(name)
        if value:
            return value, f"用户环境 {name}"
    return "", ""


def key_source() -> str:
    return _lookup()[1] or "未设置"


def api_key() -> str:
    key, _where = _lookup()
    if key:
        return key
    names = " 或 ".join(_key_names())
    raise ArkError(
        f"没有可用的 API key：在项目设置的 API 页填写，或用环境变量 {names}。"
    )


def _request(method: str, path: str, body: dict | None = None, timeout: int = 120) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base_url() + path, data=data, method=method)
    req.add_header("Authorization", "Bearer " + api_key())
    req.add_header("Content-Type", "application/json")
    last = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", "replace")
            if exc.code in (429, 500, 502, 503, 504) and attempt < 2:
                last = detail
                time.sleep(2 + attempt * 3)
                continue
            raise ArkError(f"HTTP {exc.code} {path}: {detail}") from exc
        except urllib.error.URLError as exc:
            raise ArkError(f"network error on {path}: {exc}") from exc
    raise ArkError(f"giving up on {path}: {last}")


def _download(url: str, target: Path, timeout: int = 180) -> Path:
    target.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        target.write_bytes(resp.read())
    return target


def data_url(path: Path, mime: str = "image/png") -> str:
    return f"data:{mime};base64," + base64.b64encode(Path(path).read_bytes()).decode()


def generate_image(model: str, prompt: str, target: Path, size: str = "1024x1024",
                   reference: Path | None = None, log=print) -> Path:
    """Text-to-image, optionally with one reference image (image-to-image)."""
    body = {
        "model": model,
        "prompt": prompt,
        "size": size,
        "response_format": "url",
        "watermark": False,
    }
    if reference is not None:
        body["image"] = data_url(Path(reference))
    log(f"image: {model} {size}" + (" + reference" if reference else ""))
    answer = _request("POST", "/images/generations", body, timeout=180)
    items = answer.get("data") or []
    if not items:
        raise ArkError(f"no image returned: {json.dumps(answer, ensure_ascii=False)[:400]}")
    item = items[0]
    if item.get("url"):
        _download(item["url"], target)
    elif item.get("b64_json"):
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(base64.b64decode(item["b64_json"]))
    else:
        raise ArkError("image response had neither url nor b64_json")
    # the CDN serves JPEG even when the URL ends in .png - normalise the payload
    if target.suffix.lower() == ".png":
        try:
            from PIL import Image as _Image

            with _Image.open(target) as img:
                if img.format != "PNG":
                    img.convert("RGBA" if img.mode in ("RGBA", "LA", "P") else "RGB").save(target, "PNG")
        except Exception as exc:
            log(f"  could not normalise {target.name} to PNG: {exc}")
    return target


def create_video(model: str, prompt: str, first_frame: Path, duration: int = 5,
                 resolution: str = "480p", ratio: str = "auto",
                 last_frame: Path | None = None, reference_video: str | None = None,
                 log=print) -> str:
    content = [{"type": "text", "text": prompt}]
    content.append({
        "type": "image_url",
        "image_url": {"url": data_url(Path(first_frame))},
        "role": "first_frame",
    })
    if last_frame is not None:
        content.append({
            "type": "image_url",
            "image_url": {"url": data_url(Path(last_frame))},
            "role": "last_frame",
        })
    if reference_video:
        content.append({
            "type": "video_url",
            "video_url": {"url": reference_video},
            "role": "reference_video",
        })
    body = {"model": model, "content": content, "duration": duration, "resolution": resolution}
    if ratio and ratio != "auto":
        body["ratio"] = ratio
    log(f"video: {model} {resolution} {duration}s")
    answer = _request("POST", "/contents/generations/tasks", body, timeout=120)
    task_id = answer.get("id")
    if not task_id:
        raise ArkError(f"no task id: {json.dumps(answer, ensure_ascii=False)[:400]}")
    return task_id


def wait_video(task_id: str, target: Path, log=print, interval: float = 8.0,
               timeout: float = 1200.0) -> dict:
    started = time.time()
    last_status = ""
    last_tick = 0.0
    while True:
        elapsed = time.time() - started
        if elapsed - last_tick >= 15.0:
            last_tick = elapsed
            log(f"  still rendering… {int(elapsed)}s")
        info = _request("GET", "/contents/generations/tasks/" + task_id, timeout=60)
        status = info.get("status", "?")
        if status != last_status:
            log(f"  task {task_id}: {status}")
            last_status = status
        if status == "succeeded":
            url = (info.get("content") or {}).get("video_url")
            if not url:
                raise ArkError("task succeeded without video_url")
            _download(url, target)
            info["saved"] = str(target)
            return info
        if status in ("failed", "expired", "cancelled"):
            raise ArkError(f"task {task_id} {status}: {json.dumps(info, ensure_ascii=False)[:400]}")
        if time.time() - started > timeout:
            raise ArkError(f"task {task_id} timed out after {timeout:.0f}s")
        time.sleep(interval)


def generate_video(model: str, prompt: str, target: Path, **kwargs) -> dict:
    log = kwargs.pop("log", print)
    task_id = create_video(model, prompt, log=log, **kwargs)
    return wait_video(task_id, target, log=log)


def estimate_video_tokens(resolution: str, duration: int) -> int:
    pixels = {"480p": 640 * 640, "720p": 960 * 960, "1080p": 1920 * 1080}
    return int(pixels.get(resolution, 640 * 640) * 24 * duration / 1024)


def describe_image(model: str, instruction: str, image_path: Path, log=print,
                   max_tokens: int = 900) -> str:
    """Ask a vision model to look at one image and answer in text."""
    body = {
        "model": model,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": instruction},
                {"type": "image_url", "image_url": {"url": data_url(Path(image_path))}},
            ],
        }],
        "temperature": 0.2,
        "max_tokens": max_tokens,
    }
    log(f"vision: {model} reading {Path(image_path).name}")
    answer = _request("POST", "/chat/completions", body, timeout=180)
    choices = answer.get("choices") or []
    if not choices:
        raise ArkError(f"no completion: {json.dumps(answer, ensure_ascii=False)[:300]}")
    return (choices[0].get("message") or {}).get("content", "").strip()


def chat_text(model: str, instruction: str, log=print, max_tokens: int = 900) -> str:
    """Plain text completion (no image). Used to rewrite a prompt."""
    body = {
        "model": model,
        "messages": [{"role": "user", "content": instruction}],
        "temperature": 0.8,
        "max_tokens": max_tokens,
    }
    log(f"text: {model}（等待返回，通常 30–90 秒）")
    answer = _request("POST", "/chat/completions", body, timeout=120)
    choices = answer.get("choices") or []
    if not choices:
        raise ArkError(f"no completion: {json.dumps(answer, ensure_ascii=False)[:300]}")
    return (choices[0].get("message") or {}).get("content", "").strip()


def list_models(prefixes: tuple[str, ...] = ()) -> list[str]:
    """Model ids the account can see, optionally filtered by id prefix."""
    answer = _request("GET", "/models", timeout=30)
    rows = answer.get("data") or answer.get("models") or []
    ids = [row.get("id", "") for row in rows if row.get("id")]
    if prefixes:
        ids = [i for i in ids if any(i.startswith(p) for p in prefixes)]
    return sorted(ids)


def probe_image_models(ids: list[str]) -> list[str]:
    """Cheap activation probe: a deliberately invalid size costs nothing and
    returns InvalidParameter when the model is open, ModelNotOpen when it is not.
    """
    open_ids = []
    for model in ids:
        try:
            _request("POST", "/images/generations",
                     {"model": model, "prompt": "x", "size": "7x7"}, timeout=25)
            open_ids.append(model)          # accepted the bad size, treat as open
        except ArkError as exc:
            text = str(exc)
            if "ModelNotOpen" not in text and "NotFound" not in text:
                open_ids.append(model)      # a plain validation error = model exists and is open
    return open_ids
