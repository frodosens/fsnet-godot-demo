extends RefCounted
# Bounded presentation-only interpreter. No commands, IO, animation await chains.
const EMOTES=['question','exclamation','ellipsis','sweat','anger','relief']
var scene_id=''
var cues=[]
var index=0
var elapsed_ms=0
var revealed=false
var paused=false
var bubbles={}
var bubble_ms={}
var looks={}
static func valid(data):
 if not data is Dictionary or not data.get('id') is String or not data.get('cues') is Array or data.cues.size()>128:return false
 var ids={}
 for c in data.cues:
  if not c is Dictionary or not c.get('id') is String or ids.has(c.id):return false
  ids[c.id]=true
  match c.get('op'):
   'say':
    if not c.get('speaker') is String or not c.get('text') is String or c.text.is_empty() or c.text.length()>500:return false
   'beat':
    if not c.get('ms') is int or c.ms<0 or c.ms>1500:return false
   'bubble':
    if not c.get('actor') is String or c.get('emotion') not in EMOTES:return false
   'look':
    if not c.get('actor') is String or c.get('direction') not in ['front_left','front_right','back_left','back_right']:return false
   _:return false
 return true
func start(data):
 if not valid(data):return false
 scene_id=data.id;cues=data.cues.duplicate(true);index=0;elapsed_ms=0;revealed=false;paused=false;bubbles.clear();bubble_ms.clear();looks.clear();drain();return true
func drain():
 while index<cues.size():
  var c=cues[index]
  if c.op in ['say','beat']:return
  if c.op=='bubble':bubbles[c.actor]=c.emotion;bubble_ms[c.actor]=800
  if c.op=='look':looks[c.actor]=c.direction
  index+=1
func current():return cues[index] if index<cues.size() else {}
func advance():
 if paused or current().is_empty():return
 if current().op=='say' and not revealed:revealed=true;return
 index+=1;elapsed_ms=0;revealed=false;bubbles.clear();drain()
func tick(ms):
 if paused or not ms is int or ms<0:return
 for actor in bubble_ms.keys():
  bubble_ms[actor]-=ms
  if bubble_ms[actor]<=0:bubble_ms.erase(actor);bubbles.erase(actor)
 if not current().is_empty() and current().op=='beat':
  elapsed_ms=mini(current().ms,elapsed_ms+ms)
  if elapsed_ms>=current().ms:advance()
func skip():
 if paused:return
 # No effects are executed while skipping. Only final cosmetic facing is reconstructed.
 for c in cues:
  if c.op=='look':looks[c.actor]=c.direction
 index=cues.size();elapsed_ms=0;revealed=false;bubbles.clear()
func save():return {'scene':scene_id,'index':index,'elapsed_ms':elapsed_ms,'revealed':revealed}
func restore(data,s):
 if not valid(data) or not s is Dictionary or s.get('scene')!=data.id or not s.get('index') is int or s.index<0 or s.index>data.cues.size() or not s.get('elapsed_ms') is int or s.elapsed_ms<0 or not s.get('revealed') is bool:return false
 if s.index<data.cues.size():
  var c=data.cues[s.index]
  if c.op not in ['say','beat'] or s.elapsed_ms>(c.ms if c.op=='beat' else 0):return false
 elif s.elapsed_ms!=0:return false
 start(data);index=s.index;elapsed_ms=s.elapsed_ms;revealed=s.revealed;bubbles.clear();looks.clear()
 for i in range(index):
  if cues[i].op=='look':looks[cues[i].actor]=cues[i].direction
 return true
