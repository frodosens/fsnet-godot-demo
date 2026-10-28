extends SceneTree
const C=preload('res://logic/content.gd')
const R=preload('res://logic/runtime.gd')
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():call_deferred('run')
func run():
 var d=C.chapter_three_content();check(C.validate(d).is_empty(),'valid chapter three')
 check(d.width==10 and d.height==9 and d.units.size()==5,'approved grid and two guards')
 check(not preload('res://view/authored_scene.gd').profile(d).is_empty(),'contract-specific scene admitted')
 var edges=0
 for y in range(9):
  for x in range(10):
   if d.terrain[y][x] in ['W','X']:continue
   for delta in [Vector2i.RIGHT,Vector2i.DOWN]:
    var end=Vector2i(x,y)+delta
    if end.x>=10 or end.y>=9 or d.terrain[end.y][end.x] in ['W','X']:continue
    var fixture=d.duplicate(true);fixture.units=[fixture.units[0]];fixture.units[0].x=x;fixture.units[0].y=y
    var probe=R.new(fixture)
    var accepted=probe.apply_command({'kind':'move','unit':0,'x':end.x,'y':end.y,'step':1})
    if Vector2i(x,y)==Vector2i(8,1):check(not accepted and probe.outcome=='victory','goal-start fixture already terminal')
    else:check(accepted,'Lua adjacency '+str(Vector2i(x,y))+' -> '+str(end))
    edges+=1
 check(edges==96,'all96 adjacency fixtures')
 var r=R.new(d);var trace=[]
 check(r.path_to(0,Vector2i(4,7)).is_empty(),'ally destination forbidden')
 check(not r.path_to(0,Vector2i(5,7)).is_empty(),'ally traversal permitted')
 var blocked=d.duplicate(true);blocked.units[3].x=5;blocked.units[3].y=7
 check(R.new(blocked).path_to(0,Vector2i(5,7)).is_empty(),'enemy destination forbidden')
 var loss=R.new(d)
 for point in [Vector2i(3,4),Vector2i(2,3)]:
  check(loss.apply_command({'kind':'move','unit':0,'x':point.x,'y':point.y,'step':loss.step+1}),'loss route')
  check(loss.apply_command({'kind':'end_turn','step':loss.step+1}),'loss AI approach')
 for turn in range(15):
  if loss.outcome!='playing':break
  check(loss.apply_command({'kind':'end_turn','step':loss.step+1}),'natural guard AI')
 check(loss.outcome=='defeat' and loss.units[0].hp==0,'protect-Mara natural defeat')
 for p in [Vector2i(6,7),Vector2i(8,6),Vector2i(8,3),Vector2i(8,1)]:
  var c={'kind':'move','unit':0,'x':p.x,'y':p.y,'step':r.step+1};trace.append(c.duplicate());check(r.apply_command(c),'legal approach '+str(p))
  if p!=Vector2i(8,1):
   c={'kind':'end_turn','step':r.step+1};trace.append(c.duplicate());check(r.apply_command(c),'AI turn')
 check(r.outcome=='victory','natural reach victory')
 check(r.units[3].hp>0 and r.units[4].hp>0,'no all-kill requirement')
 var replay=R.new(d)
 for c in trace:check(replay.apply_command(c),'replay command')
 check(replay.state_hash()==r.state_hash(),'same replay hash')
 var app=root.get_node('App');app.save_root='user://ch3_'+str(Time.get_ticks_usec())
 app.new_game(C.chapter_two_content())
 for p in [Vector2i(3,4),Vector2i(3,2),Vector2i(6,2),Vector2i(8,1)]:
  check(app.session.submit({'kind':'move','unit':0,'x':p.x,'y':p.y}),'chapter two natural move')
  if p!=Vector2i(8,1):check(app.session.submit({'kind':'end_turn'}),'chapter two AI')
 check(not app.next_chapter_ready(),'ending dialogue gates entry')
 while not app.next_story().is_empty():app.advance_story(true)
 check(app.next_chapter_ready(),'chapter two ready')
 var before=app.session.logic.snapshot();var hash=app.session.logic.state_hash();var story=app.presentation.duplicate(true)
 check(app.save_slot('slot1').is_empty(),'manual save retained')
 var manual=FileAccess.get_file_as_bytes(app.save_path('slot1'))
 app.session.online=true;check(not app.enter_next_chapter() and app.session.logic.snapshot()==before,'online cannot swap content');app.session.online=false
 var slot=app.checkpoint_id(app.session.logic.rules_hash,app.session.logic.content_hash,before,story)
 check(slot.begins_with('chapter2_end_'),'separate namespace')
 DirAccess.make_dir_recursive_absolute(app.save_path(slot)+'.tmp')
 check(not app.enter_next_chapter() and app.session.logic.snapshot()==before,'write failure blocks transition')
 DirAccess.remove_absolute(app.save_path(slot)+'.tmp')
 check(app.enter_next_chapter(),'entry succeeds')
 check(app.session.logic.content.id==d.id and app.session.logic.round_number==1,'fresh chapter preset')
 check(not app.next_chapter_ready(),'no chapter four')
 var bytes=FileAccess.get_file_as_bytes(app.save_path(slot))
 check(app.save_slot('auto').is_empty(),'chapter three autosave')
 check(FileAccess.get_file_as_bytes(app.save_path(slot))==bytes and FileAccess.get_file_as_bytes(app.save_path('slot1'))==manual,'checkpoint and manual intact')
 check(app.load_slot(slot) and app.session.logic.snapshot()==before and app.session.logic.state_hash()==hash and app.presentation==story,'exact ch2 inventory state and story restored')
 check(app.enter_next_chapter() and FileAccess.get_file_as_bytes(app.save_path(slot))==bytes,'repeat transition retains bytes')
 check(app.load_slot('auto') and app.session.logic.content.id==d.id,'reload chapter3 embedded content')
 check(not app.save_slot(slot).is_empty(),'normal save cannot overwrite checkpoint')
 var forged=slot.replace('chapter2_end_','chapter1_end_')
 var f=FileAccess.open(app.save_path(forged),FileAccess.WRITE);f.store_buffer(bytes);f.close()
 check(not app.inspect_slot(forged).error.is_empty(),'checkpoint prefix cannot impersonate chapter one')
 check(app.is_chapter_checkpoint('chapter1_end_'+'a'.repeat(64)) and app.is_chapter_checkpoint('chapter2_end_'+'b'.repeat(64)),'both established namespaces recognized')
 check(not app.is_chapter_checkpoint('chapter3_end_'+'a'.repeat(64)) and not app.is_chapter_checkpoint('../chapter2_end_'+'a'.repeat(64)),'unknown namespace and path rejected')
 check(not C.write_mod(d).is_empty(),'built-in chapter3 ID protected')
 print('CHAPTER_THREE checks=',checks,' failures=',failures,' reach_hp=',r.units[0].hp)
 quit(1 if failures else 0)
