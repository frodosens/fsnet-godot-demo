#!/usr/bin/env python3
"""Technical square-reference registration only. Requires Pillow and numpy.
No bounding-box fitting, limb editing, warping, or bottom alignment.
"""
import argparse, hashlib, json
from pathlib import Path
from PIL import Image
import numpy as np

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('source', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--alpha-floor', type=int, default=8)
a = p.parse_args()
if not 0 <= a.alpha_floor <= 255:
    p.error('alpha-floor must be 0..255')
if a.output.exists() or a.output.with_suffix('.registration.json').exists():
    p.error('refusing to overwrite an existing candidate or receipt')
im = Image.open(a.source).convert('RGBA')
if im.width != im.height:
    p.error('expected square output from square reference; inspect rather than stretch')
original_size = im.size
pixels = np.array(im)
pixels[pixels[:, :, 3] < a.alpha_floor, 3] = 0
im = Image.fromarray(pixels).resize((128, 128), Image.Resampling.NEAREST)
im = im.crop((16, 0, 112, 128))
a.output.parent.mkdir(parents=True, exist_ok=True)
im.save(a.output)
alpha = np.array(im)[:, :, 3]
last = {}
for threshold in (1, 8, 128, 240, 255):
    ys = np.where(alpha >= threshold)[0]
    last[str(threshold)] = int(ys.max()) if len(ys) else None
receipt = {
    'source_sha256': hashlib.sha256(a.source.read_bytes()).hexdigest(),
    'output_sha256': hashlib.sha256(a.output.read_bytes()).hexdigest(),
    'source_size': original_size, 'output_size': im.size,
    'alpha_floor': a.alpha_floor, 'resize': 'uniform full square to128, nearest',
    'crop': [16, 0, 112, 128], 'root': [48, 120],
    'bbox_exclusive_end': im.getbbox(), 'last_occupied_y_by_alpha': last,
    'art_review': 'pending', 'runtime_clipping': 'pending',
}
a.output.with_suffix('.registration.json').write_text(json.dumps(receipt, indent=2)+'\n')
print(json.dumps(receipt, indent=2))
