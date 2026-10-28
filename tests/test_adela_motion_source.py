#!/usr/bin/env python3
"""Runtime-only source integrity; no provider metadata or image processing dependency."""
import hashlib,json,pathlib,struct
root=pathlib.Path(__file__).resolve().parents[1]
base=root/'assets/sprites/iso4/adela_video_two_panel_walk'
source=json.loads((base/'motion_manifest.json').read_text())
profile=json.loads((root/'assets/animations/adela_motion_trial.json').read_text())['profiles']['adela']
assert profile['motion_only'] is True
assert source['root']==[64,120] and source['canvas']==[128,128]
assert source['frame_weights']==[3,3,3,3,4,3,3,3]
assert len(source['frames'])==16
assert len(list(base.rglob('*.png')))==16
checks=5
for frame in source['frames']:
    path=base/frame['file'];assert path.is_relative_to(base)
    data=path.read_bytes();assert hashlib.sha256(data).hexdigest()==frame['sha256']
    assert data[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24])==(128,128)
    assert frame['weight']==source['frame_weights'][frame['frame']]
    checks+=4
for direction,mapping in source['direction_sources'].items():
    clip=profile[direction]['motion'];assert clip['flip_h']==mapping['mirrorX']==direction.endswith('right')
    assert clip['ticks']==source['frame_weights'] and clip['cycle_ticks']==25 and clip['root']==[64,120]
    assert clip['frames']==[f'assets/sprites/iso4/adela_video_two_panel_walk/motion/{mapping["source"]}/{mapping["source"]}_walk_{i:02d}.png' for i in range(8)]
    assert profile[direction]['neutral_guard']==f'assets/characters/reserve/adela/map/{direction}.png'
    checks+=4
assert profile['front_left']['motion']['frames']==profile['front_right']['motion']['frames'];checks+=1
print(f'ADELA_MOTION_SOURCE checks={checks} failures=0')
