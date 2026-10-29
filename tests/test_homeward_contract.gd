extends "res://tests/support/test_case.gd"
const C=preload('res://logic/content.gd')
const R=preload('res://logic/runtime.gd')
const Player=preload('res://story/player.gd')
func _initialize():call_deferred('run')
func run():
 var scenes=C.normalize(JSON.parse_string(FileAccess.get_file_as_string('res://story/scenes.json')))
 for data in scenes.values():
  check(Player.valid(data),'valid scene '+data.id)
  var p=Player.new();check(p.start(data),'start')
  while not p.current().is_empty():
   var before=p.save();p.paused=true;p.tick(9999);p.advance();p.skip();check(p.save()==before,'pause immutable');p.paused=false
   var q=Player.new();check(q.restore(data,before) and q.save()==before,'cursor restore')
   p.advance()
  p.skip();check(p.bubbles.is_empty(),'finished bubbles clear')
 for i in range(1,4):
  var loaded=C.from_file('res://content/homeward/ch0%d.json'%i)
  check(loaded.error.is_empty(),str(loaded.error))
  if not loaded.error.is_empty():continue
  var d=loaded.data;var r=R.new(d)
  check(r.units.filter(func(u):return u.controller=='player').size()==(2 if i<3 else 3),'party size')
  check(not r.apply_command({'kind':'finish_story','event_id':d.id+'_finish','step':1}),'unwon battle cannot finish')
  check(r.content.id=='homeward_0'+str(i),'new content identity')
 var bubble=Player.new();bubble.start({'id':'probe','cues':[{'id':'e','op':'bubble','actor':'neri','emotion':'anger'},{'id':'s','op':'say','speaker':'neri','text':'嗯。'}]})
 bubble.tick(799);check(bubble.bubbles.has('neri'),'bubble holds bounded duration');bubble.paused=true;bubble.tick(999);check(bubble.bubbles.has('neri'),'paused emote frozen');bubble.paused=false;bubble.tick(1);check(bubble.bubbles.is_empty(),'bubble expires without advancing text')
 check(not Player.valid({'id':'bad','cues':[{'id':'x','op':'stage_note'}]}),'authoring is not code')
 print('homeward contract ',checks,' checks; failures=',failures);quit(1 if failures else 0)
