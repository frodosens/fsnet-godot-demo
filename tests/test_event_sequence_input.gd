extends "res://tests/support/test_case.gd"
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func click(p):
 var move=InputEventMouseMotion.new();move.position=p;root.push_input(move,true);await frames(2)
 for down in [true,false]:
  var e=InputEventMouseButton.new();e.position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await frames(2)
func find_button(node,text):
 if node is Button and node.text==text:return node
 for child in node.get_children():
  var result=find_button(child,text)
  if result:return result
 return null
func run():
 var app=root.get_node('App');app.sfx_enabled=false
 for size in [Vector2i(1280,800),Vector2i(960,600)]:
  root.size=size
  var data=preload('res://logic/content.gd').reference_content()
  data.units[3].x=4;data.units[3].y=6;data.units[4].x=6;data.units[4].y=7;data.units[5].x=7;data.units[5].y=8
  app.new_game(data);change_scene_to_file('res://main.tscn');await frames(8)
  while not app.next_story().is_empty():app.advance_story(true)
  var g=current_scene;g.refresh();await frames(3)
  await click(g.hud.turn_button.get_global_rect().get_center())
  var confirm=find_button(g.hud.root,'确认结束');check(confirm!=null,'mouse opened end-turn confirmation '+str(size))
  if confirm==null:quit(1);return
  await click(confirm.get_global_rect().get_center())
  check(g.battle.step==1 and g.event_sequence.active(),'mouse confirmation starts sequenced AI')
  var truth=g.battle.snapshot();var selected=g.selected
  await click(g.hud.turn_button.get_global_rect().get_center())
  await click(g.camera.unproject_position(g.figures[1].position))
  check(g.battle.snapshot()==truth and g.selected==selected,'queued playback blocks duplicate commands and board reselection')
  check(not is_instance_valid(g.hud.modal),'no stale confirmation during queue')
  g.motion.speed=8;g.cutin.speed=8
  var deadline=Time.get_ticks_msec()+10000
  while g.presentation_active() and Time.get_ticks_msec()<deadline:await process_frame
  check(not g.presentation_active(),'queue finishes at accelerated presentation speed')
  while not app.next_story().is_empty():app.advance_story(true)
  g.hud.refresh();await frames(3)
  await click(g.hud.turn_button.get_global_rect().get_center())
  check(is_instance_valid(g.hud.modal),'input resumes after queue')
  g.hud.clear_modal()
 print('EVENT_SEQUENCE_INPUT checks=',checks,' failures=',failures,' actual_mouse=true resolutions=1280/960')
 quit(1 if failures else 0)
