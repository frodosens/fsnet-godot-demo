"""Validate admitted atlas bytes, transparent grid, and real per-phase variation."""
from pathlib import Path
import hashlib,json
from PIL import Image
root=Path(__file__).resolve().parents[1]/'assets/effects/map_spells'
contract=json.loads((root/'atlas_contract.json').read_text())
checks=0
for name, expected in contract['files'].items():
    path=root/name
    assert hashlib.sha256(path.read_bytes()).hexdigest()==expected;checks+=1
    image=Image.open(path)
    assert image.mode=='RGBA' and image.size==(384,384);checks+=1
    hashes=[]
    for i in range(16):
        frame=image.crop((i%4*96,i//4*96,(i%4+1)*96,(i//4+1)*96))
        alpha=frame.getchannel('A');bbox=alpha.getbbox()
        assert bbox and alpha.getextrema()[0]==0;checks+=1
        assert bbox[0]>=10 and bbox[1]>=10 and bbox[2]<=86 and bbox[3]<=86;checks+=1
        hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
    for start,end in [(0,4),(4,8),(8,16)]:
        assert len(set(hashes[start:end]))==end-start;checks+=1
print(f'MAP_SPELL_ASSETS checks={checks} failures=0 styles=3 frames_per_style=4/4/8 bytes_preserved=true')
