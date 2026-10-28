"""Runtime asset/export admission, using only the Python standard library."""
import fnmatch, hashlib, json, pathlib, re, struct
ROOT=pathlib.Path(__file__).resolve().parents[1]
base=ROOT/'assets/characters/chapter3'
checks=0
def check(value):
    global checks
    assert value
    checks+=1
def walk_hashes(node):
    if isinstance(node,dict):
        if 'path' in node and 'sha256' in node:
            path=base/node['path']
            if path.is_file():check(hashlib.sha256(path.read_bytes()).hexdigest()==node['sha256'])
        for v in node.values():walk_hashes(v)
    elif isinstance(node,list):
        for v in node:walk_hashes(v)
for file in base.glob('*_contract.json'):walk_hashes(json.loads(file.read_text()))
images=list(base.rglob('*.png'))
check(len(images)==36)
for p in images:
    raw=p.read_bytes();check(raw[:8]==b'\x89PNG\r\n\x1a\n')
    expected=(512,512) if p.name=='portrait.png' else (192,160) if 'battle' in p.parts else (128,128)
    check(struct.unpack('>II',raw[16:24])==expected)
preset=(ROOT/'export_presets.cfg').read_text()
include=re.search(r'^include_filter="(.*)"$',preset,re.M)[1].split(',')
exclude=re.search(r'^exclude_filter="(.*)"$',preset,re.M)[1].split(',')
required=['assets/characters/chapter3/map_contract.json','assets/characters/chapter3/battle_contract.json','assets/animations/vera_chapter_motion.json','content/mill_receipts.json','assets/backgrounds/sluice_watchhouse/map-background-contract.json','assets/backgrounds/sluice_watchhouse/battle-background-contract.json']
for path in required:
    check((ROOT/path).is_file())
    check(any(fnmatch.fnmatchcase(path,p) for p in include))
    check(not any(fnmatch.fnmatchcase(path,p) for p in exclude))
print(f'CHAPTER_GUARD_ASSETS checks={checks} failures=0')
