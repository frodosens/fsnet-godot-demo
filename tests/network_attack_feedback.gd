extends SceneTree
var checks=0
func check(ok,label):
 checks+=1
 if not ok:printerr('FAIL: ',label);quit(1)
 assert(ok,label)
func _initialize():call_deferred('run')
func run():
 var app=root.get_node('App');app.mobile_presentation=true;root.size=Vector2i(2400,1080)
 var data=load('res://logic/content.gd').from_file(OS.get_environment('AMBER_MOD')).data
 check(app.start_room(false,int(OS.get_environment('AMBER_TEST_PORT')),OS.get_environment('AMBER_TOKEN'),data),'real authority connect')
 var deadline=Time.get_ticks_msec()+15000
 while not app.session.ready or app.session.pending:
  await process_frame
  if Time.get_ticks_msec()>deadline:quit(1);return
 while not app.next_story().is_empty():app.advance_story(true)
 change_scene_to_file('res://main.tscn');await process_frame;await process_frame
 var g=current_scene
 while app.session.pending:await process_frame
 g.select_actor(2);g.scene_view.cancel_focus();g.selection_pending_focus=false;g.select_mode('attack')
 var point=g.camera.unproject_position(Vector3(5,0,7))
 for tap in range(2):
  for down in [true,false]:
   var e=InputEventScreenTouch.new();e.index=0;e.pressed=down;e.position=point;root.push_input(e,true);await process_frame
  await process_frame
  if tap==0:check(g.battle.step==0 and not g.pending_target.is_empty(),'real first touch previews')
 while g.battle.step<1:
  await process_frame
  if Time.get_ticks_msec()>deadline:quit(1);return
 check(g.presentation_active() and g.cutin.active and g.selected==2,'network attack visibly gated')
 var truth=g.battle.snapshot();var rid=g.battle.get_instance_id();var replacements=0;var last_age=0.0
 while g.presentation_active():
  if g.battle.get_instance_id()!=rid:rid=g.battle.get_instance_id();replacements+=1
  if g.cutin.active:
   var age=g.cutin.elapsed;check(age>=last_age,'poll never restarts age');last_age=age
  check(g.battle.snapshot()==truth and g.selected==2,'poll cannot mutate result or change actor')
  check(not g.wait_selected(),'wait gated during attack')
  await process_frame
  if Time.get_ticks_msec()>deadline:quit(1);return
 check(replacements>=2,'ordinary Runtime replacements observed')
 var end=Time.get_ticks_msec()+450
 while Time.get_ticks_msec()<end:await process_frame
 check(g.battle.step==1 and not g.presentation_active() and g.selected==2,'no replay or auto-next after completion')
 var offline=load('res://logic/runtime.gd').new(data);check(offline.apply_command({'kind':'attack','unit':2,'target':3,'step':1}),'offline same action');check(offline.snapshot()==truth,'offline and online identical')
 print('NETWORK_ATTACK_FEEDBACK checks=',checks,' failures=0 replacements=',replacements)
 app.close_room();quit()
