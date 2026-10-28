extends SceneTree
func _initialize():call_deferred('run')
func frames(n=3):
 for i in range(n):await process_frame
func touch(p):
 for down in [true,false]:
  var e=InputEventScreenTouch.new();e.position=p;e.index=0;e.pressed=down;root.push_input(e,true);await process_frame
 await frames(2)
func run():
 var app=root.get_node('App');app.mobile_presentation=true;root.size=Vector2i(2400,1080)
 for actor in [0,1,2]:
  var d=load('res://logic/content.gd').reference_content()
  d.units[0].x=2;d.units[0].y=7;d.units[1].x=2;d.units[1].y=8;d.units[2].x=3;d.units[2].y=8
  d.units[actor].x=4;d.units[actor].y=7;d.units[3].x=5;d.units[3].y=7
  assert(load('res://logic/content.gd').validate(d).is_empty())
  app.new_game(d)
  while not app.next_story().is_empty():app.advance_story(true)
  change_scene_to_file('res://main.tscn');await frames(8)
  var g=current_scene;g.select_actor(actor);g.scene_view.cancel_focus();g.selection_pending_focus=false;g.select_mode('attack');await frames(3)
  var p=g.camera.unproject_position(Vector3(5,0,7));var before=g.battle.units[3].hp
  await touch(p);print('PROPOSAL ',g.battle.units[actor].id,' ',not g.pending_target.is_empty())
  await touch(p)
  print('ATTACK_RESULT actor=',g.battle.units[actor].id,' before=',before,' after=',g.battle.units[3].hp,' acted=',g.battle.units[actor].acted,' step=',g.battle.step,' selected=',g.selected,' cutin=',g.cutin.active,' queue=',g.event_sequence.active(),' heal_numbers=',g.heal_feedback.numbers.size(),' events=',g.battle.events)
  g.skip_presentation()
 quit()
