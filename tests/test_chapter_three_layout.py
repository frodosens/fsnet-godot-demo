"""Approved chapter-three layout: topology only, not art/AI balance acceptance."""
import json
from collections import deque
from pathlib import Path
p=Path(__file__).resolve().parents[1]
d=json.loads((p/'content/mill_receipts.json').read_text())
expected=['XXXXXXXXXX','XDDDDDDDDX','XDDDXXDDDX','XDDDXXDDDX','WWBBWWWBBW','GDDDDDDDDG','GDDGXXGDDG','GDDDDDDDDG','GGGGGGGGGG']
assert d['terrain']==expected
assert len(d['units'])==5
blocked={(u['x'],u['y']) for u in d['units'] if not u['ally']}
assert blocked=={(3,3),(6,2)}
def path(extra):
    queue=deque([((3,7),0)]);seen={(3,7)}
    while queue:
        (x,y),cost=queue.popleft()
        if (x,y)==(8,1):return cost
        for n in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
            a,b=n
            if 0<=a<10 and 0<=b<9 and expected[b][a] not in 'WX' and n not in seen|blocked|extra:
                seen.add(n);queue.append((n,cost+1))
    return None
assert path({(7,4),(8,4)})==13
assert path({(2,4),(3,4)})==11
assert path({(2,4),(3,4),(7,4),(8,4)}) is None
assert sum(c not in 'WX' for row in expected for c in row)==62
assert len({(u['x'],u['y']) for u in d['units']})==5
assert d['victory']=={'kind':'reach','unit':'mara','x':8,'y':1}
assert d['defeat']=={'kind':'protect','unit':'mara'}
print('CHAPTER_THREE_LAYOUT: approved topology, two routes 13/11, no water bypass')
