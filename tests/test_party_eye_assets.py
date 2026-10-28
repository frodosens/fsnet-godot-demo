#!/usr/bin/env python3
"""Runtime-only hash, alpha and original portrait identity contract."""
import hashlib,json,pathlib
from PIL import Image
root=pathlib.Path(__file__).resolve().parents[1]
folder=root/'assets/ui/party_eye_v2'
manifest=json.loads((folder/'manifest.json').read_text())
checks=0
for name,entry in manifest['assets'].items():
    path=folder/entry['file']; image=Image.open(path)
    assert image.size==tuple(entry['size_px']) and image.mode=='RGBA';checks+=1
    assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'];checks+=1
    if 'portrait_rect_px' in entry:
        x,y,w,h=entry['portrait_rect_px']
        assert image.getchannel('A').crop((x,y,x+w,y+h)).getextrema()==(0,0);checks+=1
        assert image.size==(272,120) and not entry['nine_patch'];checks+=1
assert len(list(folder.glob('*.png')))==10;checks+=1
print(f'PARTY_EYE_ASSETS checks={checks} failures=0')
