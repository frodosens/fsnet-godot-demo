extends "res://tests/support/test_case.gd"
func _initialize():call_deferred('run')
func run():
 var app=root.get_node('App')
 var data=Content.from_file(OS.get_environment('AMBER_MOD')).data
 check(app.start_room(false,int(OS.get_environment('AMBER_TEST_PORT')),OS.get_environment('AMBER_TOKEN'),data),'connect authority')
 var deadline=Time.get_ticks_msec()+45000
 while not app.session.ready or app.session.pending:
  await process_frame
  if Time.get_ticks_msec()>deadline:quit(1);return
 change_scene_to_file('res://main.tscn');await process_frame;await process_frame
 while not app.next_story().is_empty():app.advance_story(true)
 var g=current_scene;g.refresh()
 while app.session.pending:await process_frame
 check(app.session.submit({'kind':'move','unit':0,'x':3,'y':3}),'network move through two allies')
 while g.battle.step<1 or g.presentation_active():
  await process_frame
  if Time.get_ticks_msec()>deadline:quit(1);return
 var route=g.battle.events[0].path
 check(route.size()==4 and route[1].x==1 and route[2].x==2,'authority path contains occupied allied transit cells')
 check(g.battle.units[0].pos==Vector2i(3,3),'empty endpoint reached')
 g.event_sequence.trace.clear()
 while app.session.pending:await process_frame
 check(app.session.submit({'kind':'end_turn'}),'network actual AI turn')
 while g.battle.step<2:
  await process_frame
  if Time.get_ticks_msec()>deadline:quit(1);return
 var truth=g.battle.snapshot();var emitted=g.battle.events.duplicate(true)
 var replacements=0;var runtime_id=g.battle.get_instance_id();var progress={};var samples=0
 while g.presentation_active():
  check(g.motion.motions.size()<=1,'one mover')
  if runtime_id!=g.battle.get_instance_id():replacements+=1;runtime_id=g.battle.get_instance_id()
  for id in g.motion.motions:
   var distance=g.motion.motions[id].travelled
   check(distance+.00001>=progress.get(id,0.0),'poll does not replay '+id);progress[id]=distance
  check(g.battle.snapshot()==truth,'visuals never change authority');samples+=1
  await process_frame
  if Time.get_ticks_msec()>deadline:check(false,'presentation timeout');break
 var expected=[]
 for e in emitted:expected.append({'kind':e.kind,'actor':e.get('actor',''),'step':2})
 check(g.event_sequence.trace==expected,'real network move/action exact ordering')
 check(replacements>=2 and samples>20,'ordinary Runtime replacements observed')
 var until=Time.get_ticks_msec()+600
 while Time.get_ticks_msec()<until:await process_frame
 check(not g.presentation_active() and g.event_sequence.trace==expected,'completed batch not replayed')
 var offline=Runtime.new(data);check(offline.apply_command({'kind':'move','unit':0,'x':3,'y':3,'step':1}),'offline allied move');check(offline.apply_command({'kind':'end_turn','step':2}),'offline same AI command')
 check(offline.snapshot()==truth,'offline/network canonical equality')
 print('NETWORK_EVENT_SEQUENCE failures=',failures,' replacements=',replacements,' samples=',samples,' trace=',expected)
 app.session.transport.shutdown();quit(1 if failures else 0)
