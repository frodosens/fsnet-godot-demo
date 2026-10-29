from pathlib import Path
import hashlib,json
from PIL import Image
root=Path(__file__).resolve().parents[1]
new=root/'assets/sprites/iso4/neri_idle_standing_v1'
old=root/'assets/sprites/iso4/neri_seedance_mini_v2'
manifest=json.loads((new/'art_manifest.json').read_text())
assert 'source_task_id' not in manifest
for frame in manifest['frames']:
 p=new/frame['file'];assert hashlib.sha256(p.read_bytes()).hexdigest()==frame['sha256']
 im=Image.open(p);assert im.mode=='RGBA' and im.size==(160,160)
 assert im.getchannel('A').getbbox()[3]<=144
source=json.loads((old/'art_manifest.json').read_text())
for f in source['frames']:
 assert hashlib.sha256((old/f['file']).read_bytes()).hexdigest()==f['sha256'],'old resource changed'
runtime=json.loads((old/'runtime_manifest.json').read_text())['profiles']['neri']
for d in ['front_left','front_right','back_left','back_right']:
 entry=runtime[d];left=d.replace('right','left')
 assert entry['idle']['frames']==['assets/sprites/iso4/neri_idle_standing_v1/'+left+'_idle_00.png']
 assert entry['idle']['flip_h']==entry['motion']['flip_h']==d.endswith('right')
 assert entry['idle']['root']==entry['motion']['root']==[80,144]
assert len([f for f in source['frames'] if f['kind']=='motion'])==16
print('NERI_STANDING_ASSETS two new hashes, 18 retained hashes, four roots/mirrors, alpha ends at or above root: PASS')
