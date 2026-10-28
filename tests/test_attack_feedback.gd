extends SceneTree
var checks=0
var app
var g
func check(ok,label):
 checks+=1
 assert(ok,label)
func _initialize():call_deferred('run')
func frames(n=3):
 for i in range(n):await process_frame
func touch(cell):
 var p=g.camera.unproject_position(Vector3(cell.x,0,cell.y))
 for down in [true,false]:
  var e=InputEventScreenTouch.new();e.index=0;e.position=p;e.pressed=down;root.push_input(e,true);await process_frame
 await frames(2)
func fresh(actor=2,hp=6,armor=0):
 var d=load('res://logic/content.gd').reference_content()
 d.units[0].x=2;d.units[0].y=7;d.units[1].x=2;d.units[1].y=8;d.units[2].x=3;d.units[2].y=8
 d.units[actor].x=4;d.units[actor].y=7;d.units[3].x=5;d.units[3].y=7;d.units[3].hp=hp;d.units[3].armor=armor
 check(load('res://logic/content.gd').validate(d).is_empty(),'valid legal fixture')
 app.new_game(d)
 while not app.next_story().is_empty():app.advance_story(true)
 change_scene_to_file('res://main.tscn');await frames(6);g=current_scene
 g.select_actor(actor);g.scene_view.cancel_focus();g.selection_pending_focus=false;g.select_mode('attack');await frames()
func settle():
 var n=0
 while g.presentation_active() and n<600:
  await process_frame;n+=1
 check(not g.presentation_active() and g.heal_feedback.numbers.is_empty(),'feedback finishes without duplicate map damage')
func run():
 app=root.get_node('App');app.mobile_presentation=true;root.size=Vector2i(1280,800) if OS.get_environment('ATTACK_SMALL')=='1' else Vector2i(2400,1080)
 for actor in [0,1,2]:
  await fresh(actor)
  var before=g.battle.snapshot();var hp=g.battle.units[3].hp
  await touch(Vector2i(5,7));check(g.battle.snapshot()==before and not g.pending_target.is_empty(),'first touch only previews')
  await touch(Vector2i(5,7));check(g.battle.step==1 and g.battle.units[actor].acted and g.battle.units[3].hp<hp,'second touch commits exactly one attack')
  check(g.selected==actor and g.presentation_active(),'visible feedback with selection unchanged')
  check(g.cutin.active and g.heal_feedback.numbers.is_empty(),'authored cutin for every supported ordinary attack')
  if actor==2:
   check(g.cutin.event.damage==hp-g.battle.units[3].hp and g.cutin.event.ability=='attack','actual ordinary attack event')
   if not OS.get_environment('ATTACK_CAPTURE').is_empty():
    await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OS.get_environment('ATTACK_CAPTURE'))
  var truth=g.battle.snapshot();check(not g.wait_selected() and not g.select_actor((actor+1)%3),'wait/reselection blocked during attack feedback')
  await touch(Vector2i(5,7));check(g.battle.snapshot()==truth,'repeat touch cannot spend another action')
  await settle();check(g.selected==actor and g.battle.snapshot()==truth,'no automatic switch or logic mutation')
  # Duplicate releases and touch-generated mouse events are not new Wait commands.
  var target_point=g.camera.unproject_position(Vector3(5,0,7))
  var wait_button=g.hud.dock.action_nodes.wait
  check(not wait_button.get_global_rect().has_point(target_point),'target is not behind Wait button')
  check(not wait_button.get_global_rect().intersects(g.hud.dock.confirm.get_global_rect()),'confirm and Wait hit rectangles separate')
  for point in [target_point,wait_button.get_global_rect().get_center()]:
   var release=InputEventScreenTouch.new();release.index=0;release.position=point;release.pressed=false;root.push_input(release,true)
   var mouse=InputEventMouseButton.new();mouse.device=-1;mouse.position=point;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=false;root.push_input(mouse,true)
   await frames()
  for down in [true,false]:
   var mouse=InputEventMouseButton.new();mouse.device=-1;mouse.position=target_point;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=down;root.push_input(mouse,true)
   await frames()
  check(g.selected==actor and g.battle.snapshot()==truth,'duplicate touch/mouse release cannot trigger Wait or auto-next')

 # Invalid, dead and out-of-range targets never consume action or create feedback.
 await fresh();var before=g.battle.snapshot()
 for p in [Vector2i(8,1),Vector2i(6,7),Vector2i(7,2)]:
  await touch(p);await touch(p);check(g.battle.snapshot()==before and not g.presentation_active(),'invalid/unreachable click no effect or switch')
 await fresh(2,1);await touch(Vector2i(5,7));await touch(Vector2i(5,7));check(g.battle.units[3].hp==0,'lethal actual event')
 check(g.figures[3].visible,'lethal target held visible through feedback');await settle();check(not g.figures[3].visible,'death settles after feedback')
 before=g.battle.snapshot();await touch(Vector2i(5,7));await touch(Vector2i(5,7));check(g.battle.snapshot()==before,'dead target cannot receive attack')
 # High armor is minimum one damage in current Lua, never a silent zero/miss.
 await fresh(2,6,20);await touch(Vector2i(5,7));await touch(Vector2i(5,7));check(g.battle.events[0].damage==1 and g.cutin.event.damage==1,'minimum damage feedback');g.skip_presentation()
 # Move -> attack -> explicit Wait, no action or actor advance while visual feedback runs.
 await fresh();check(app.session.submit({'kind':'move','unit':2,'x':4,'y':6}),'legal movement');g.refresh();await settle();g.select_mode('attack')
 await touch(Vector2i(5,7));await touch(Vector2i(5,7));check(g.battle.step==2 and not g.wait_selected(),'move attack cannot prematurely advance')
 await settle();check(g.selected==2,'attack never autoswitches');check(g.wait_selected() and g.selected==0,'only explicit Wait advances spent actor')
 # Pending poll is queued once; busy command invalidates a stale proposal.
 await fresh();await touch(Vector2i(5,7));g.session.pending=true
 check(g.confirm_proposal() and not g.queued_confirmation.is_empty() and g.battle.step==0,'poll queues confirmation')
 g.session.pending=false;g.flush_confirmation();check(g.battle.step==1 and g.presentation_active(),'queued attack receives feedback');g.flush_confirmation();check(g.battle.step==1,'queue consumed once');g.skip_presentation()
 await fresh();await touch(Vector2i(5,7));g.session.command_pending=true
 check(not g.confirm_proposal() and g.battle.step==0 and not g.battle.units[2].acted,'busy command rejects no spend');g.session.command_pending=false
 # Same-step Runtime replacement does not restart the local display timer.
 await fresh();await touch(Vector2i(5,7));await touch(Vector2i(5,7));g.cutin.set_process(false)
 g.cutin._process(.2);var age=g.cutin.elapsed;var truth=g.battle.snapshot()
 var r=load('res://logic/runtime.gd').new(g.battle.content);check(r.restore(truth),'restore authoritative replacement')
 app.session.logic=r;g.battle=r;g.refresh();check(g.cutin.active and g.cutin.elapsed==age,'same-step poll no replay')
 g.skip_presentation();check(g.heal_feedback.numbers.is_empty() and not g.presentation_active() and g.battle.snapshot()==truth,'skip finalizes latest state')
 print('ATTACK_FEEDBACK checks=',checks,' failures=0 touchscreen=true rules_unchanged=true')
 quit()
