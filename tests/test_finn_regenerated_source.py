"""Bound the Finn opt-in profile to the reviewed extraction; do not alter art."""
import hashlib,json,pathlib,struct
root=pathlib.Path(__file__).resolve().parents[1]
base=root/'assets/sprites/iso4/finn_video_regen_20261028'
source=json.loads((base/'source_manifest.json').read_text())
profile=json.loads((root/'assets/animations/map_sequences.json').read_text())['profiles']['finn']
assert source['source_indices']==[42,45,48,51,54,58,61,64]
assert source['cycle_end_exclusive']==67
weights=[3,3,3,3,4,3,3,3]
assert source['frame_weights']==weights and sum(weights)==25
assert profile['motion_only'] is True
assert len(source['runtime_frames'])==32
for frame in source['runtime_frames']:
    data=(root/frame['path']).read_bytes()
    assert hashlib.sha256(data).hexdigest()==frame['sha256']
    assert data[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack('>II',data[16:24])==(128,128)
for direction in ('front_left','front_right','back_left','back_right'):
    entry=profile[direction];motion=entry['motion']
    assert 'idle' not in entry and '/idle_candidate/finn/' in entry['neutral_guard']
    assert motion['ticks']==weights and motion['root']==[64,120] and motion['cycle_ticks']==25
    expected=[f'assets/sprites/iso4/finn_video_regen_20261028/motion/{direction}/{direction}_walk_{i:02}.png' for i in range(8)]
    assert motion['frames']==expected
    # Old experimental resources remain an explicit rollback option in Git.
    for p in expected:assert (root/p.replace('finn_video_regen_20261028/','finn_video_compact/')).is_file()
assert 'assets/sprites/iso4/finn_video_regen_20261028/source_manifest.json' in (root/'export_presets.cfg').read_text()
print('FINN_REGENERATED_SOURCE: 32 hashes/canvases, four weighted bindings, original idle/fallback and provenance export exclusion verified')
