extends "res://tests/support/test_case.gd"
func _initialize():call_deferred('run')
func frames(n=4):
 for i in range(n):await process_frame
func tap(game,target):
 var pos=game.camera.unproject_position(Vector3(target.x,0,target.y))
 for down in [true,false]:
  var e=InputEventScreenTouch.new();e.index=0;e.position=pos;e.pressed=down;root.push_input(e,true);await process_frame
 await frames(2)
func run():
 var app=root.get_node('App');app.mobile_presentation=true
 for size in [Vector2i(1280,800),Vector2i(2400,1080)]:
  root.size=size
  var data=preload('res://logic/content.gd').reference_content()
  for p in [[3,4,6],[4,3,7],[5,5,7]]:data.units[p[0]].hp=1;data.units[p[0]].x=p[1];data.units[p[0]].y=p[2]
  app.new_game(data)
  while not app.next_story().is_empty():app.advance_story(true)
  change_scene_to_file('res://main.tscn');await frames(8)
  var g=current_scene
  for i in range(3):
   g.select_actor(i);g.scene_view.cancel_focus();g.selection_pending_focus=false;g.select_mode('attack');await frames()
   var target=g.battle.units[i+3]
   await tap(g,target);await tap(g,target)
   check(g.battle.step==i+1,'real touch attack accepted')
   g.skip_presentation();await frames()
  check(g.battle.outcome=='victory' and not g.presentation_active(),'XP event drains without presentation deadlock')
  for i in range(3):check(g.battle.units[i].level==2 and g.battle.units[i].xp==60,'visible game runtime receives terminal growth')
  while not app.next_story().is_empty():app.advance_story(true)
  g.refresh();await frames()
  check(app.next_chapter_ready(),'victory dialogue remains completable')
 print('PROGRESSION_SCENE checks=',checks,' failures=',failures,' resolutions=1280x800/2400x1080 touchscreen=true')
 quit(1 if failures else 0)
