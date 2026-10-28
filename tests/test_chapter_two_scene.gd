extends SceneTree
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():call_deferred('run')
func frames(n=4):
 for i in range(n):await process_frame
func button(prefix,node):
 for b in node.find_children('*','Button',true,false):
  if b.is_visible_in_tree() and not b.disabled and b.text.begins_with(prefix):return b
 return null
func click(b):
 check(b!=null,'visible button')
 if b==null:return
 var p=b.get_global_rect().get_center()
 for pressed in [true,false]:
  var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=p;e.pressed=pressed;root.push_input(e,true);await process_frame
 await frames()
func run():
 var app=root.get_node('App');app.save_root='user://chapter2_scene';app.scene_renderer='auto'
 var C=load('res://logic/content.gd')
 for viewport in [Vector2i(1280,800),Vector2i(960,600)]:
  root.size=viewport
  var fixture=C.reference_content();fixture.units[3].hp=1;fixture.units[3].x=4;fixture.units[3].y=6;fixture.units[4].hp=1;fixture.units[4].x=3;fixture.units[4].y=7;fixture.units[5].hp=1;fixture.units[5].x=5;fixture.units[5].y=7
  app.new_game(fixture)
  for pair in [[0,3],[1,4],[2,5]]:app.session.submit({'kind':'attack','unit':pair[0],'target':pair[1]})
  change_scene_to_file('res://main.tscn');await frames(8);current_scene.skip_presentation();await frames()
  check(not current_scene.hud.chapter_button.visible,'next hidden during ending')
  await click(button('跳过本段',current_scene.hud.story_panel));check(current_scene.hud.chapter_button.visible,'next after ending')
  await click(current_scene.hud.chapter_button);await click(button('保存结尾并进入第二章',current_scene.hud.modal));await frames(8)
  var game=current_scene
  check(game.battle.content.id=='white_elm_watchhouse','actual UI entered chapter two')
  check(game.scene_view.active and game.scene_view.backdrop!=null,'ordinary entry uses chapter two painting')
  check(game.hud.story_panel.visible and not game.hud.dock.visible,'chapter intro blocks footer')
  await click(button('下一句',game.hud.story_panel));await click(button('暂停 / 保存',game.hud.story_panel));await click(button('继续战斗',game.hud.modal));await click(button('跳过本段',game.hud.story_panel))
  var truth=game.battle.snapshot();var factor=root.get_visible_rect().size.y/800.0
  print('CH2_PROJECTION ',viewport,' actual=',game.camera.unproject_position(Vector3(8,0,1)),' expected=',Vector2(927.64,389)*factor)
  check(game.camera.unproject_position(Vector3(8,0,1)).distance_to(Vector2(927.64,389)*factor)<0.1,'door projection')
  check(game.mouse_cell(game.camera.unproject_position(Vector3(8,0,1)))==Vector2i(8,1),'picking aligned')
  check(is_equal_approx(game.character_scale,1.25),'same actor scale')
  var pos=game.camera.position
  check(game.scene_view.set_fixed(false),'3D switch');check(not game.camera.position.is_equal_approx(pos),'3D original camera restored')
  check(game.scene_view.set_fixed(true) and game.camera.position.is_equal_approx(pos),'fixed camera restored without accumulated shift')
  check(game.battle.snapshot()==truth,'renderer toggles preserve hash')
  game.hud.choose_action('move');game.update_move_preview(Vector2i(3,4));check(game.preview_path.size()==4,'actual Lua path preview')
  game.clear_move_preview();check(game.battle.snapshot()==truth,'cancel no command')
  var capture=OS.get_environment('AMBER_CH2_CAPTURE')
  if not capture.is_empty():
   await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(capture+'/chapter2-'+str(viewport.x)+'.png')
  # A valid adjacent battle fixture proves chapter-specific cut-in art, not a playthrough.
  var battle_data=C.chapter_two_content();battle_data.units[3].x=3;battle_data.units[3].y=6
  var runtime=load('res://logic/runtime.gd').new(battle_data);check(runtime.apply_command({'kind':'attack','unit':0,'target':3,'step':1}),'legal chapter-two cut-in fixture')
  game.cutin.consume(100,runtime.events,runtime.units,battle_data)
  check(game.cutin.reference_background.visible and game.cutin.reference_background.texture.resource_path.ends_with('white_elm_watchhouse/battle.png'),'sideview chapter background')
  check(game.cutin.combat_status.portraits.right.flip_h,'right portrait fix preserved')
  game.cutin.finish()
 check(C.reference_content().terrain[7][0]=='X','first chapter obstacle unchanged')
 print('CHAPTER_TWO_SCENE checks=',checks,' failures=',failures)
 quit(1 if failures else 0)
