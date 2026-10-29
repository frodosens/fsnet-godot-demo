"""Offline integrity checks for the six map catalog entries (Pillow dev-only)."""
from pathlib import Path
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
catalog=json.loads((ROOT/'assets/animations/generic_map_library.json').read_text())
assert catalog['version']==1
expected={'generic_soldier_01','generic_knight_01','generic_beast_01','generic_caster_01','generic_archer_01','generic_bandit_01'}
assert set(catalog['profiles'])==expected
count=0
for identity,spec in catalog['profiles'].items():
 base=ROOT/spec['base'];assert spec['binding']=='exact_unit_id' and spec['campaign_spawns'] is False
 receipt=base/('animation_manifest.json' if identity=='generic_soldier_01' else 'art_manifest.json')
 data=json.loads(receipt.read_text());assert data['character_id']==identity and data['canvas']==[160,160] and data['root']==[80,144]
 assert 'source_task_id' not in data
 files=set()
 for frame in data['frames']:
  p=ROOT/frame['file'] if frame['file'].startswith('assets/') else base/frame['file']
  assert p.is_relative_to(base) and '..' not in p.parts
  assert hashlib.sha256(p.read_bytes()).hexdigest()==frame['sha256']
  im=Image.open(p);assert im.mode=='RGBA' and im.size==(160,160)
  assert im.getchannel('A').getbbox() is not None
  files.add(p);count+=1
 assert len(files)==18 and files==set(base.rglob('*.png'))
 manifest=json.loads((ROOT/spec['manifest']).read_text());assert manifest['version']==2 and set(manifest['profiles'])=={identity}
 for direction in ['front_left','front_right','back_left','back_right']:
  d=manifest['profiles'][identity][direction];flip=direction.endswith('right')
  assert len(d['idle']['frames'])==1 and len(d['motion']['frames'])==8
  for state in ['idle','motion']:
   clip=d[state];assert clip['root']==[80,144] and clip['flip_h']==flip
   assert sum(clip['ticks'])==clip['cycle_ticks'] and all(isinstance(t,int) and 0<t<=38 for t in clip['ticks'])
   assert all(ROOT/p in files for p in clip['frames'])
print(f'GENERIC_ASSETS {count} RGBA PNG hashes; six complete controlled map catalogs')
