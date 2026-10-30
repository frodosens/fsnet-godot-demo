"""Measure an artifact with plain image analysis.

Used when no vision model is available: we can still correct the next prompt
from the previous result - palette, background colour and head/body proportions
are measurable without any API call, so the prompt stops drifting away from the
art that was actually produced.
"""
from __future__ import annotations

import colorsys
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

MARKER = "｜外观参照上一步产物："

MODEL_DIR = Path(__file__).resolve().parent.parent / "models"
MODEL_CANDIDATES = ["modnet.onnx", "modnet_quantized.onnx"]  # fp32 first: the
# int8 export loses the body and keeps only specular highlights
BIREFNET_DIR = MODEL_DIR / "birefnet"
RVM_DIR = MODEL_DIR / "rvm"
RVM_CODE = RVM_DIR / "RobustVideoMatting-master"
RVM_WEIGHTS = RVM_DIR / "rvm_mobilenetv3.pth"
_RVM_CACHE: dict = {}


def torch_device():
    """cuda when a CUDA build of torch is installed, otherwise cpu."""
    try:
        import torch

        if torch.cuda.is_available():
            return torch.device("cuda")
    except Exception:
        pass
    return None


def device_name() -> str:
    try:
        import torch

        if torch.cuda.is_available():
            return f"cuda:{torch.cuda.get_device_name(0)}"
    except Exception:
        pass
    return "cpu"


def matte_model_path() -> Path | None:
    """Learned matting model, if one was downloaded."""
    import os

    override = os.environ.get("ASSETGEN_MATTE_MODEL")
    if override and Path(override).exists():
        return Path(override)
    for name in MODEL_CANDIDATES:
        candidate = MODEL_DIR / name
        if candidate.exists():
            return candidate
    return None


_RUNTIME_STATE: dict = {}


def preload_msvc_runtime() -> dict:
    """Load the real MSVC runtime before onnxruntime can pick a stray copy.

    A machine may have an old msvcp140.dll in a PATH entry (TortoiseSVN ships one
    from 2020). onnxruntime is built against a newer runtime and dies with an
    access violation, which takes the whole process - GUI included - down. Loading
    System32's copy first makes every later name lookup reuse it.
    """
    if _RUNTIME_STATE:
        return _RUNTIME_STATE
    import ctypes
    import os

    root = os.environ.get("SystemRoot", r"C:\Windows")
    loaded = []
    for name in ("msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll",
                 "vcruntime140.dll", "vcruntime140_1.dll", "concrt140.dll"):
        candidate = os.path.join(root, "System32", name)
        if not os.path.exists(candidate):
            continue
        try:
            ctypes.WinDLL(candidate)
            loaded.append(name)
        except OSError:
            pass
    _RUNTIME_STATE["loaded"] = loaded
    _RUNTIME_STATE["path"] = loaded_runtime_path()
    return _RUNTIME_STATE


def loaded_runtime_path() -> str:
    """Where msvcp140.dll actually came from, for the log."""
    try:
        import ctypes
        from ctypes import wintypes

        k32 = ctypes.WinDLL("kernel32", use_last_error=True)
        k32.GetModuleHandleW.argtypes = [wintypes.LPCWSTR]
        k32.GetModuleHandleW.restype = wintypes.HMODULE
        k32.GetModuleFileNameW.argtypes = [wintypes.HMODULE, wintypes.LPWSTR, wintypes.DWORD]
        handle = k32.GetModuleHandleW("msvcp140.dll")
        if not handle:
            return ""
        buffer = ctypes.create_unicode_buffer(1024)
        k32.GetModuleFileNameW(handle, buffer, 1024)
        return buffer.value
    except Exception:
        return ""


def learned_matte(image: Image.Image, model_path: Path | None = None,
                  max_side: int = 1024) -> Image.Image | None:
    """MODNet matte as an 8-bit mask, or None when onnxruntime/model is absent."""
    path = model_path or matte_model_path()
    if path is None:
        return None
    state = preload_msvc_runtime()
    where = state.get("path") or ""
    if where and "system32" not in where.lower() and "pythons" not in where.lower():
        # another msvcp140.dll won the race; onnxruntime would crash the process
        _RUNTIME_STATE["unsafe"] = where
        return None
    try:
        import onnxruntime as ort

        session = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
    except Exception:
        return None

    rgb = image.convert("RGB")
    scale = min(1.0, max_side / max(rgb.size))
    width = max(32, int(round(rgb.width * scale / 32)) * 32)
    height = max(32, int(round(rgb.height * scale / 32)) * 32)
    small = rgb.resize((width, height), Image.LANCZOS)
    arr = np.asarray(small, dtype=np.float32) / 127.5 - 1.0
    tensor = arr.transpose(2, 0, 1)[None, ...]

    name = session.get_inputs()[0].name
    out = session.run(None, {name: tensor})[0][0, 0]
    matte = np.clip(out, 0.0, 1.0)
    mask = Image.fromarray((matte * 255).astype(np.uint8), "L")
    return mask.resize(rgb.size, Image.LANCZOS)


def _rgb(value) -> str:
    return "#%02x%02x%02x" % tuple(int(v) for v in value[:3])


def _is_background(rgb, bg, tol=26) -> bool:
    return sum(abs(int(rgb[i]) - int(bg[i])) for i in range(3)) <= tol


def measure(path: Path, max_side: int = 512) -> dict:
    img = Image.open(path).convert("RGB")
    img.thumbnail((max_side, max_side), Image.LANCZOS)
    a = np.array(img)
    bg = a[2, 2, :].astype(int)
    flat = a.reshape(-1, 3)
    keep = np.array([not _is_background(p, bg) for p in flat[: min(len(flat), 80000)]])
    sample = flat[: min(len(flat), 80000)][keep]

    colours = []
    if len(sample):
        quant = (sample // 24 * 24).astype(int)
        for value, _count in Counter(map(tuple, quant)).most_common(4):
            colours.append(_rgb(np.add(np.array(value, dtype=int), 12)))

    mask = ~np.all(np.abs(a.astype(int) - bg) <= 8, axis=2)
    ys, xs = np.where(mask)
    if len(ys):
        height = int(ys.max() - ys.min() + 1)
        width = int(xs.max() - xs.min() + 1)
        ratio = height / max(1, width)
    else:
        height = width = 0
        ratio = 0.0

    return {
        "background": _rgb(bg),
        "palette": colours,
        "body_height_px": height,
        "body_width_px": width,
        "height_width_ratio": round(ratio, 2),
        "canvas": list(img.size),
    }


def describe(path: Path) -> str:
    m = measure(path)
    palette = "、".join(m["palette"]) if m["palette"] else "（无法取样）"
    return (
        f"{MARKER}背景 {m['background']}；主色 {palette}；"
        f"角色包围盒 {m['body_width_px']}×{m['body_height_px']} px，高宽比约 {m['height_width_ratio']}。"
        "下一步必须沿用同样的配色、同样的背景色和同样的头身比例。"
    )


def apply(prompt: str, path: Path) -> str:
    """Replace any previous measured clause with a fresh one."""
    base = prompt.split(MARKER)[0].rstrip()
    return base + "\n" + describe(path)



def border_region(mask: np.ndarray) -> np.ndarray:
    """True for background-like pixels connected to the image border."""
    if not mask.any():
        return mask.copy()
    try:
        from scipy import ndimage

        labels, count = ndimage.label(mask)
        if count == 0:
            return np.zeros_like(mask, dtype=bool)
        edge = np.concatenate([labels[0, :], labels[-1, :], labels[:, 0], labels[:, -1]])
        touching = np.unique(edge[edge > 0])
        return np.isin(labels, touching)
    except Exception:
        # dependency-free fallback: scanline flood fill from every border pixel
        seen = np.zeros_like(mask, dtype=bool)
        stack = [(y, x) for y in (0, mask.shape[0] - 1) for x in range(mask.shape[1])
                 if mask[y, x]]
        stack += [(y, x) for x in (0, mask.shape[1] - 1) for y in range(mask.shape[0])
                  if mask[y, x]]
        h, w = mask.shape
        while stack:
            y, x = stack.pop()
            if not (0 <= y < h and 0 <= x < w) or seen[y, x] or not mask[y, x]:
                continue
            seen[y, x] = True
            stack.extend(((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)))
        return seen


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


def _erode_mask(mask: np.ndarray, radius: int) -> np.ndarray:
    out = mask.copy()
    for _ in range(radius):
        shrunk = out.copy()
        shrunk[1:, :] &= out[:-1, :]
        shrunk[:-1, :] &= out[1:, :]
        shrunk[:, 1:] &= out[:, :-1]
        shrunk[:, :-1] &= out[:, 1:]
        out = shrunk
    return out


def _erode(alpha: np.ndarray, radius: int) -> np.ndarray:
    """Shrink the silhouette: hard pixels inside, zero on the removed rim."""
    solid = _erode_mask(alpha > 0.5, radius)
    return np.where(solid, np.maximum(alpha, 0.999), 0.0)


def _edge_band(alpha: np.ndarray, radius: int = 3) -> np.ndarray:
    """Ring straddling the silhouette boundary - spill lives on both sides."""
    solid = alpha > 0.5
    return _dilate(solid, radius) & ~_erode_mask(solid, radius)


def shadow_mask(rgb: np.ndarray, bg: np.ndarray, alpha: np.ndarray, band: float = 0.25,
                tolerance: float = 14.0, spread: float = 0.05) -> np.ndarray:
    """Ground shadow = the backdrop scaled down by the same factor in every channel.

    A shadow *multiplies* the backdrop, so dividing it out gives the backdrop back
    and all three channels share one ratio. Boots and armour are merely dark-ish
    colours: their per-channel ratio differs, which is what ``spread`` rejects.
    Restricting to the bottom band keeps the test away from the torso.
    """
    safe = np.maximum(bg, 1.0)
    per_channel = rgb / safe
    ratio = per_channel.mean(axis=2)
    deviation = np.abs(per_channel - ratio[..., None]).max(axis=2)
    residual = np.abs(rgb - bg[None, None, :] * ratio[..., None]).max(axis=2)
    suspect = ((ratio > 0.40) & (ratio < 0.92) & (deviation < spread)
               & (residual < tolerance))
    if band > 0:
        rows = np.where((alpha > 0.5).any(axis=1))[0]
        if rows.size:
            top, bottom = int(rows.min()), int(rows.max())
            start = int(bottom - (bottom - top) * min(1.0, band))
            suspect[:max(0, start)] = False
    return suspect


def remove_background(src: Path, dst: Path, tolerance: int = 30, pad: int = 4,
                      expected: str = "", soft: bool = True, despill: bool = True,
                      method: str = "auto", shadow: bool = False,
                      shadow_band: float = 0.18, matte_side: int = 1024,
                      matte_threshold: float = 0.5, matte_gamma: float = 1.0,
                      trim: int = 0) -> dict:
    """Key out the flat backdrop of a generated image.

    ``soft``   turns the hard threshold into a distance ramp, which removes the
               staircase on hair and cloth edges.
    ``despill`` un-composites partial pixels with C = a*F + (1-a)*B, so the edge
               stops carrying the backdrop colour.
    Only the region connected to the border is touched: dark clothing that
    happens to sit near the backdrop colour survives.
    """
    im = Image.open(src).convert("RGB")
    arr = np.array(im).astype(np.float32)
    corners = arr[[0, 0, -1, -1], [0, -1, 0, -1]]
    # Key on what is actually there; the declared colour is only a sanity check.
    # Overriding bg with the declared colour would raise the distance of real
    # backdrop pixels whenever the model drifts a little.
    bg = np.median(corners, axis=0)

    # A saturated key colour (magenta) is a real chroma screen: the colour key is
    # exact there, while MODNet - trained on natural photos - calls magenta
    # foreground and leaves blobs behind. So the network is skipped.
    chroma = float(bg.max() - bg.min()) > 120
    if chroma:
        tolerance = max(tolerance, 80)
        if method not in ("key", "birefnet"):
            method = "key"
    distance = np.abs(arr - bg).sum(axis=2)
    low, high = tolerance * 0.65, tolerance * 1.9
    if soft:
        alpha = np.clip((distance - low) / max(1e-6, high - low), 0.0, 1.0)
    else:
        alpha = (distance > tolerance).astype(np.float32)

    used_method = "key"
    if method == "birefnet":
        matte = birefnet_matte(im, size=max(512, matte_side))
        if matte is not None:
            learned = np.asarray(matte, dtype=np.float32) / 255.0
            if matte_gamma != 1.0:
                learned = np.clip(learned, 0.0, 1.0) ** max(0.05, matte_gamma)
            if matte_threshold > 0:
                learned = np.where(learned < matte_threshold, 0.0, learned)
            if chroma:
                alpha = np.where(distance <= low, 0.0, learned)
            else:
                alpha = learned
            used_method = "birefnet"
        else:
            used_method = "key-birefnet-unavailable"

    if method in ("auto", "learned", "hybrid", "edge", "net"):
        matte = learned_matte(im, max_side=matte_side)
        if matte is not None:
            learned = np.asarray(matte, dtype=np.float32) / 255.0
            if matte_gamma != 1.0:
                # >1 keeps only the confident core, <1 lets the soft edge survive
                learned = np.clip(learned, 0.0, 1.0) ** max(0.05, matte_gamma)
            if matte_threshold > 0:
                # pull everything below the cut-off to zero, keep the rest as-is
                learned = np.where(learned < matte_threshold, 0.0, learned)
            if method in ("net", "auto"):
                # The network gives clean edges and keeps details whose colour is
                # close to the backdrop, but it also punches holes in large flat
                # areas (dark capes). Union with the colour key keeps those solid;
                # the border-connected pass then removes the real background.
                alpha = np.maximum(learned, alpha)
                used_method = "net"
            elif method == "edge":
                # use the network only inside a narrow band around the keyed
                # boundary: pixel art has large flat areas the network tends to
                # see through, but its edge shape is better than a threshold.
                band = ((alpha > 0.02) & (alpha < 0.98)).astype(np.uint8) * 255
                grown = np.array(Image.fromarray(band, "L").filter(ImageFilter.MaxFilter(5))) > 0
                alpha = alpha.copy()
                alpha[grown] = learned[grown]
                used_method = "edge"
            elif method == "learned":
                # trust the network, only force the obvious background away
                alpha = np.where(distance <= low, 0.0, learned)
                used_method = "learned"
            else:
                # hybrid: the network gives the edge shape, the flat key vetoes
                # anything it is confident is backdrop (this is what removes the
                # ground shadow the network keeps)
                alpha = np.minimum(learned, np.maximum(alpha, (distance > high * 3).astype(np.float32)))
                alpha = np.where(distance <= low, 0.0, alpha)
                used_method = "hybrid"
        elif method != "auto":
            used_method = "key-fallback"

    # Everything connected to the border stays background, whatever the ramp says.
    # (Pillow's floodfill silently no-ops on some builds, so label components.)
    # Seed with the *tight* threshold: a dark cape at distance 40 must not join
    # the background just because the ramp calls it partially transparent.
    outside = border_region(distance <= low)
    alpha[outside] = 0.0

    shadows = 0
    if shadow:
        suspect = shadow_mask(arr, bg, alpha, band=shadow_band)
        shadows = int(suspect.sum())
        if shadows:
            alpha = alpha.copy()
            alpha[suspect] = 0.0

    rgb = arr.copy()
    if despill and chroma:
        # Spill only lives on the soft edge. A key colour is saturated, so its two
        # bright channels are the ones that bleed; cap them at the dark channel.
        # Anything that does not carry that signature - gold trim, warm cloth -
        # is left untouched.
        edge = _edge_band(alpha)
        order = np.argsort(bg)
        dark, bright_a, bright_b = int(order[0]), int(order[1]), int(order[2])
        floor = rgb[..., dark]
        hit = edge.copy()
        for channel in (bright_a, bright_b):
            hit &= rgb[..., channel] > floor + 10
        for channel in (bright_a, bright_b):
            capped = np.minimum(rgb[..., channel], floor + 10)
            rgb[..., channel] = np.where(hit, capped, rgb[..., channel])
    if despill and soft and not chroma:
        partial = (alpha > 0.02) & (alpha < 0.98)
        if partial.any():
            a3 = alpha[partial][:, None]
            rgb[partial] = np.clip((arr[partial] - (1.0 - a3) * bg) / np.maximum(a3, 1e-3), 0, 255)

    if trim > 0:
        # the model often paints a 1px rim in the key colour; eroding the mask by
        # that many pixels removes it without touching the interior
        alpha = _erode(alpha, int(trim))

    rgba = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    rgba.putalpha(Image.fromarray(np.round(alpha * 255).astype(np.uint8)))
    bbox = rgba.getbbox()
    if bbox:
        left, top, right, bottom = bbox
        left, top = max(0, left - pad), max(0, top - pad)
        right, bottom = min(rgba.width, right + pad), min(rgba.height, bottom + pad)
        rgba = rgba.crop((left, top, right, bottom))
    dst.parent.mkdir(parents=True, exist_ok=True)
    rgba.save(dst, "PNG")

    kept = float((alpha > 0.02).mean())
    report = {"background": _rgb(bg), "kept_ratio": round(kept, 3), "chroma": chroma,
              "size": list(rgba.size), "suspicious": kept < 0.02 or kept > 0.985,
              "soft": soft, "despill": despill, "method": used_method,
              "shadow_px": shadows,
              "matches_expected": True}
    if expected:
        want = np.array([int(expected[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.int16)
        got = np.array([int(_rgb(bg)[i:i + 2], 16) for i in (1, 3, 5)], dtype=np.int16)
        # magenta is often rendered with a little noise; only flag a real mismatch
        report["matches_expected"] = float(np.abs(got - want).sum()) <= 90
    return report


def birefnet_available() -> bool:
    return (BIREFNET_DIR / "model.safetensors").exists()


def birefnet_matte(image: Image.Image, size: int = 1024) -> Image.Image | None:
    """BiRefNet matte - the best edges of the three, but ~18 s per image on CPU.

    transformers' dynamic module needs einops + kornia + timm; missing pieces make
    it return None so the caller can fall back instead of crashing.
    """
    if not birefnet_available():
        return None
    try:
        import torch
        from transformers import AutoModelForImageSegmentation
    except Exception:
        return None

    device = _RVM_CACHE.get("birefnet_device", "unset")
    if device == "unset":
        device = torch_device()
        _RVM_CACHE["birefnet_device"] = device

    model = _RVM_CACHE.get("birefnet")
    if model is None:
        try:
            model = AutoModelForImageSegmentation.from_pretrained(
                str(BIREFNET_DIR), trust_remote_code=True).eval()
        except Exception:
            return None
        if device is not None:
            model = model.to(device)
        _RVM_CACHE["birefnet"] = model

    means = torch.tensor([0.485, 0.456, 0.406], device=device).view(3, 1, 1) \
        if device is not None else torch.tensor([0.485, 0.456, 0.406]).view(3, 1, 1)
    stds = torch.tensor([0.229, 0.224, 0.225], device=device).view(3, 1, 1) \
        if device is not None else torch.tensor([0.229, 0.224, 0.225]).view(3, 1, 1)

    rgb = image.convert("RGB")
    small = rgb.resize((size, size), Image.LANCZOS)
    tensor = torch.from_numpy(np.asarray(small, dtype="float32") / 255.0).permute(2, 0, 1)
    if device is not None:
        tensor = tensor.to(device)
    tensor = ((tensor - means) / stds)[None]
    try:
        with torch.no_grad():
            logits = model(tensor)[-1]
        matte = logits[0, 0].sigmoid().cpu().numpy()
    except Exception:
        return None
    mask = Image.fromarray((np.clip(matte, 0, 1) * 255).astype(np.uint8), "L")
    return mask.resize(rgb.size, Image.LANCZOS)


def rvm_available() -> bool:
    return RVM_WEIGHTS.exists() and RVM_CODE.exists()


def _rvm_model():
    """Lazy loader for Robust Video Matting (MobileNetV3 backbone)."""
    if _RVM_CACHE.get("net") is not None:
        return _RVM_CACHE["net"]
    if not rvm_available():
        return None
    import sys

    try:
        import torch
    except Exception:
        return None

    if str(RVM_CODE) not in sys.path:
        sys.path.insert(0, str(RVM_CODE))
    from model import MattingNetwork

    device = torch_device()
    net = MattingNetwork("mobilenetv3").eval()
    net.load_state_dict(torch.load(str(RVM_WEIGHTS), map_location=device or "cpu"))
    if device is not None:
        net = net.to(device)
    _RVM_CACHE["net"] = net
    _RVM_CACHE["device"] = device
    _RVM_CACHE["torch"] = torch
    return net


def rvm_alpha_sequence(images: list[Image.Image], downsample: float = 0.5) -> list[np.ndarray] | None:
    """Matte a run of frames in order, keeping RVM's recurrent state between them.

    The memory is the whole point: a per-frame model jitters by ~2x as much on a
    walk cycle, which shows up as a breathing silhouette once the frames play.
    """
    net = _rvm_model()
    if net is None:
        return None
    import torch

    torch.set_grad_enabled(False)
    device = _RVM_CACHE.get("device")
    out: list[np.ndarray] = []
    rec: list = [None] * 4
    for image in images:
        rgb = image.convert("RGB")
        src = torch.from_numpy(np.asarray(rgb, dtype="float32") / 255.0).permute(2, 0, 1)[None]
        if device is not None:
            src = src.to(device)
        _fgr, pha, *rec = net(src, *rec, downsample_ratio=downsample)
        alpha = pha[0, 0].cpu().numpy()
        out.append(np.clip(alpha, 0.0, 1.0))
    return out
