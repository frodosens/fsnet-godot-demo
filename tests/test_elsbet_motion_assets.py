"""Validate admitted Elsbet PNGs; no generated evidence is written to the repository."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/sprites/iso4/elsbet_seedance_mini_v2'
manifest=json.loads((BASE/'art_manifest.json').read_text())
assert 'source_task_id' not in manifest
assert manifest['canvas']==[160,160] and manifest['root']==[80,144]
seen=set()
for frame in manifest['frames']:
    path=ROOT/frame['file'];assert path.is_relative_to(BASE)
    assert hashlib.sha256(path.read_bytes()).hexdigest()==frame['sha256']
    image=Image.open(path);assert image.mode=='RGBA' and image.size==(160,160)
    mask=image.getchannel('A').point(lambda alpha:255 if alpha>=128 else 0)
    if frame['kind']=='motion':assert list(mask.getbbox())==frame['alpha_bbox_exclusive']
    assert image.getchannel('A').getbbox()[3]<160
    seen.add(path)
assert len(seen)==18 and seen==set(BASE.rglob('*.png'))
for direction in ['front_left','back_left']:
    old=Image.open(ROOT/f'assets/characters/reserve/elsbet/map/{direction}.png')
    new=Image.open(BASE/f'idle/{direction}/{direction}_idle_00.png')
    expected=Image.new('RGBA',(160,160));expected.paste(old,(32,24))
    assert new.tobytes()==expected.tobytes(), 'idle must only add transparent padding'
print('ELSBET_ASSETS_PASS 18 original PNG hashes, RGBA/bounds, two exact padded idle identities')
