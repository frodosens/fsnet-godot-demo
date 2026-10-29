#!/usr/bin/env python3
"""Verify shipped bytes and metadata, without generation or runtime image scanning."""
import hashlib,json,pathlib,struct
root=pathlib.Path(__file__).resolve().parents[1]
checks=0
for hero in ('mara','finn','neri'):
    base=root/f'assets/sprites/iso4/{hero}_seedance_mini_v2'
    art=json.loads((base/'art_manifest.json').read_text())
    runtime=json.loads((base/'runtime_manifest.json').read_text())
    assert len(art['frames'])==18 and len(list(base.rglob('*.png')))==18
    assert runtime['version']==2 and list(runtime['profiles'])==[hero]
    profile=runtime['profiles'][hero];assert profile['canvas']==[160,160];checks+=3
    for frame in art['frames']:
        path=base/frame['file'];assert path.is_relative_to(base)
        data=path.read_bytes();assert hashlib.sha256(data).hexdigest()==frame['sha256']
        assert data[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24])==(160,160)
        checks+=3
    for direction in ('front_left','front_right','back_left','back_right'):
        source=direction.replace('right','left');entry=profile[direction]
        for kind in ('idle','motion'):
            clip=entry[kind]
            actual_source=clip.get('source_facing',source)
            assert actual_source in (direction.split('_')[0]+'_left',direction.split('_')[0]+'_right')
            assert clip['flip_h']==(actual_source!=direction)
            assert clip['root']==[80,144] and sum(clip['ticks'])==clip['cycle_ticks']
            assert len(clip['frames'])==(1 if kind=='idle' else 8)
            if hero=='mara' and kind=='motion' and direction.startswith('back'):
                assert clip['frames']==[f'assets/sprites/iso4/mara_back_diagonal_v1/back_right_walk_{i:02d}.png' for i in range(8)]
                assert clip['ticks']==[3,3,3,3,2,4,2,3] and actual_source=='back_right'
            elif hero=='neri' and kind=='idle':
                assert clip['frames']==[f'assets/sprites/iso4/neri_idle_standing_v1/{source}_idle_00.png']
            else:
                assert all('/'+source+'/' in p for p in clip['frames'])
            assert all((root/p).is_file() for p in clip['frames']);checks+=4
    assert profile['front_left']['idle']['frames']==profile['front_right']['idle']['frames'];checks+=1
print(f'HERO_REFRESH_SOURCE checks={checks} failures=0')
