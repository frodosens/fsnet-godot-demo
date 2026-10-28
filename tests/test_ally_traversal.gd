extends SceneTree
const C=preload('res://logic/content.gd')
const R=preload('res://logic/runtime.gd')
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL: ',label)
func _initialize():call_deferred('run')
func corridor():
 var d=C.default_content();d.width=8;d.height=10;d.terrain=[]
 for y in range(10):d.terrain.append('GGGGGGGG' if y in [3,8] else 'XXXXXXXX')
 for i in range(6):
  d.units[i].x=[0,1,2,6,6,7][i];d.units[i].y=3 if i<4 else 8
 d.units[0].movement=8
 return d
func run():
 var d=corridor();check(C.validate(d).is_empty(),'legal corridor fixture')
 var r=R.new(d);var before=r.snapshot();var cells=r.reachable(0)
 check(cells.has(Vector2i(3,3)) and cells[Vector2i(3,3)]==3,'cross two same-faction allies with real path cost')
 check(not cells.has(Vector2i(1,3)) and not cells.has(Vector2i(2,3)),'occupied allies absent from landing range')
 check(not cells.has(Vector2i(6,3)) and not cells.has(Vector2i(7,3)),'enemy blocks landing and transit')
 var path=r.path_to(0,Vector2i(5,3));check(path.size()==6 and path[1]=={'x':1,'y':3} and path[2]=={'x':2,'y':3},'path keeps allied transit nodes')
 check(r.path_to(0,Vector2i(1,3)).is_empty(),'no preview route ending on ally')
 check(not r.apply_command({'kind':'move','unit':0,'x':1,'y':3,'step':1}) and r.snapshot()==before,'occupied destination rejected without consuming state')
 check(r.apply_command({'kind':'move','unit':0,'x':5,'y':3,'step':1}),'shared command accepts allied transit')
 check(r.events[0].path==path and r.units[0].pos==Vector2i(5,3),'preview and authoritative path identical')
 var replay=R.new(d);check(replay.apply_command({'kind':'move','unit':0,'x':5,'y':3,'step':1}) and replay.snapshot()==r.snapshot(),'deterministic replay')
 check(replay.restore(r.snapshot()) and replay.snapshot()==r.snapshot(),'snapshot roundtrip')
 var blocked=d.duplicate(true);blocked.units[1].faction='other';var b=R.new(blocked)
 check(not b.reachable(0).has(Vector2i(2,3)),'same ally flag but different faction blocks')
 var reserve=d.duplicate(true);reserve.units[1].id='adela';reserve.units[2].id='elsbet';check(R.new(reserve).path_to(0,Vector2i(3,3)).size()==4,'reserve IDs do not change faction transit')
 var budget=d.duplicate(true);budget.units[0].movement=2
 check(not R.new(budget).reachable(0).has(Vector2i(3,3)),'allied traversal still spends move budget')
 budget=d.duplicate(true);budget.terrain[3]='GGGXGGGG'
 check(R.new(budget).path_to(0,Vector2i(4,3)).is_empty(),'terrain obstacle remains blocking')
 # Swap factions/controllers: an AI in the back must traverse its own allies,
 # without selecting an occupied ally as its endpoint.
 var ai=d.duplicate(true)
 for i in range(6):ai.units[i].controller='ai' if i<3 else 'player';ai.units[i].faction='red' if i<3 else 'blue'
 ai.units[3].x=5;ai.units[0].movement=4
 var a=R.new(ai);check(a.apply_command({'kind':'end_turn','step':1}),'AI turn uses legal traversal')
 check(a.events.any(func(e):return e.get('kind')=='move' and e.actor=='mara' and e.path.size()>2 and e.path[1].x==1),'AI actually crosses allied corridor')
 var occupied={}
 for u in a.units:
  if u.hp>0:check(not occupied.has(u.pos),'no live overlaps');occupied[u.pos]=true
 # A genuinely defeated unit no longer blocks occupancy.
 var dead=d.duplicate(true);dead.units[1].hp=1;dead.units[2].x=0;dead.units[2].y=8;dead.units[3].x=2;dead.units[3].damage=20
 var killed=R.new(dead);check(killed.apply_command({'kind':'end_turn','step':1}),'dead-cell fixture via actual AI')
 check(killed.units[1].hp==0 and killed.reachable(0).has(Vector2i(1,3)),'dead ally is a legal empty destination')
 # Recognized predecessor snapshots retain exact state; live protocol stays strict.
 var app=root.get_node('App');app.save_root='user://ally-compat-'+str(Time.get_ticks_usec());app.new_game(d);check(app.save_slot('slot1').is_empty(),'save current state')
 var file=app.save_path('slot1');var payload=JSON.parse_string(FileAccess.get_file_as_string(file));payload.rules_hash=R.SNAPSHOT_COMPATIBLE_RULES[0]
 var f=FileAccess.open(file,FileAccess.WRITE);f.store_string(JSON.stringify(payload));f.close()
 check(app.load_slot('slot1') and app.session.logic.snapshot()==payload.snapshot,'previous-rule save restores exact inventory/RNG/snapshot')
 payload.rules_hash='unknown';f=FileAccess.open(file,FileAccess.WRITE);f.store_string(JSON.stringify(payload));f.close();check(not app.load_slot('slot1'),'unknown rule saves still rejected')
 var authority=preload('res://logic/authority.gd').new(d)
 check(authority.handle({'rules':R.SNAPSHOT_COMPATIBLE_RULES[0],'content':r.content_hash,'client':'old-client'}).has('error'),'old network rules rejected rather than silently replayed')
 print('ALLY_TRAVERSAL checks=',checks,' failures=',failures)
 quit(1 if failures else 0)
