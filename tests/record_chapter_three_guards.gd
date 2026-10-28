extends SceneTree
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func caption(game,text):
 var label=preload('res://ui/style.gd').label(text+'\n合法测试摆位／正常模拟速度；维拉步态仍为候选',18)
 label.position=Vector2(300,100);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.hud.root.add_child(label)
func open_game(data):
 var app=root.get_node('App');app.new_game(data)
 while not app.next_story().is_empty():app.advance_story(true)
 change_scene_to_file('res://main.tscn');await frames(5)
 return current_scene
func run():
 root.size=Vector2i(1280,800);var app=root.get_node('App');app.sfx_enabled=false;app.mobile_presentation=false;app.scene_renderer='auto'
 var C=load('res://logic/content.gd')
 for route in [[Vector2i(6,5),Vector2i(8,5),'front_right'],[Vector2i(8,3),Vector2i(8,5),'front_left'],[Vector2i(8,5),Vector2i(6,5),'back_left'],[Vector2i(8,5),Vector2i(8,3),'back_right']]:
  var d=C.chapter_three_content();d.units[4].ally=true;d.units[4].x=route[0].x;d.units[4].y=route[0].y
  var g=await open_game(d);caption(g,'维拉 · '+route[2]+' · 每格一循环');g.facing.vera=route[2];g.selected=4;g.refresh_map_sequence_art('vera');g.refresh();await frames(20)
  assert(app.session.submit({'kind':'move','unit':4,'x':route[1].x,'y':route[1].y}))
  g.battle=app.session.logic;g.refresh();await frames(10)
  while g.motion.active():await process_frame
  await frames(20)
 var d=C.chapter_three_content();d.units[0].x=6;d.units[0].y=5;d.units[3].x=7;d.units[3].y=5;d.units[4].x=8;d.units[4].y=3
 var g=await open_game(d);caption(g,'双方攻击／受击演出 · 我方固定左侧');await frames(25)
 assert(app.session.submit({'kind':'attack','unit':0,'target':3}));g.battle=app.session.logic;g.refresh();await frames(160)
 assert(app.session.submit({'kind':'end_turn'}));g.battle=app.session.logic;g.refresh()
 for i in range(420):
  if g.hud.story_panel.visible:g.hud.advance(true)
  await process_frame
 d=C.chapter_three_content();d.units[0].x=6;d.units[0].y=5;d.units[4].x=8;d.units[4].y=5
 g=await open_game(d);caption(g,'维拉远程攻击 · 实际敌方回合');await frames(20)
 assert(app.session.submit({'kind':'end_turn'}));g.battle=app.session.logic;g.refresh()
 for i in range(240):
  if g.hud.story_panel.visible:g.hud.advance(true)
  await process_frame
 print('CHAPTER3_GUARD_MOVIE actual_commands=true normal_simulation_speed=true offline_recording=true')
 quit()
