extends SceneTree
var checks=0
var app
var game
var movie=false
func verify(ok,label):
 checks+=1
 if not ok:printerr('CHAPTER2_UI_FAIL ',label);quit(1)
 assert(ok,label)
func _initialize():call_deferred('run')
func frames(n=3):
 for i in range(n):await process_frame
func click(point):
 var motion=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true);await frames()
 for pressed in [true,false]:
  var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=point;e.pressed=pressed;root.push_input(e,true);await process_frame
 await frames()
func button(prefix):
 for b in current_scene.find_children('*','Button',true,false):
  if b.is_visible_in_tree() and not b.disabled and b.text.begins_with(prefix):return b
 return null
func press(prefix):
 var b=button(prefix);verify(b!=null,'button '+prefix)
 if b:await click(b.get_global_rect().get_center())
func settle():
 if movie:
  var waited=0
  while game.presentation_active() and waited<1000:waited+=1;await process_frame
  verify(not game.presentation_active(),'bounded natural presentation completion')
 else:game.skip_presentation();await frames()
 while game.hud.story_panel.visible:
  if movie:await frames(42)
  await press('下一句')
func run():
 movie=OS.get_environment('AMBER_CH2_MOVIE')=='1'
 app=root.get_node('App');app.save_root='user://chapter2_ui_'+str(Time.get_ticks_usec());app.scene_renderer='auto'
 var C=load('res://logic/content.gd')
 # Saved chapter-one victory fixture isolates the new chapter entry, not a chapter-one playthrough claim.
 var old=C.reference_content();old.units[3].hp=1;old.units[3].x=4;old.units[3].y=6;old.units[4].hp=1;old.units[4].x=3;old.units[4].y=7;old.units[5].hp=1;old.units[5].x=5;old.units[5].y=7
 app.new_game(old)
 for pair in [[0,3],[1,4],[2,5]]:verify(app.session.submit({'kind':'attack','unit':pair[0],'target':pair[1]}),'chapter-one terminal fixture')
 while not app.next_story().is_empty():app.advance_story(true)
 var chapter_one_snapshot=app.session.logic.snapshot();var chapter_one_hash=app.session.logic.state_hash()
 var chapter_one_story=app.presentation.duplicate(true)
 verify(app.save_slot('slot3').is_empty(),'old inline-content save')
 var manual_bytes=FileAccess.get_file_as_bytes(app.save_path('slot3'))
 change_scene_to_file('res://ui/menu.tscn');await frames(8)
 if movie:await frames(30)
 await press('读取存档');await press('存档三');await frames(8);game=current_scene;await settle()
 await click(game.hud.chapter_button.get_global_rect().get_center())
 if movie:await frames(45)
 await press('保存结尾并进入第二章');await frames(8);game=current_scene
 verify(game.battle.content.id=='white_elm_watchhouse','actual chapter entry');await settle()
 var checkpoints=app.loadable_slots().filter(func(slot):return app.is_chapter_checkpoint(slot))
 verify(checkpoints.size()==1,'one independent chapter checkpoint')
 var checkpoint_bytes=FileAccess.get_file_as_bytes(app.save_path(checkpoints[0]))
 # Exercise the reported loss path with actual buttons, before playing chapter two.
 await press('暂停');await press('返回主界面');await press('保存并离开');await frames(8)
 verify(app.inspect_slot('auto').data.content.id=='white_elm_watchhouse','chapter two overwrites only ordinary auto')
 verify(FileAccess.get_file_as_bytes(app.save_path(checkpoints[0]))==checkpoint_bytes,'chapter checkpoint untouched by save and leave')
 verify(FileAccess.get_file_as_bytes(app.save_path('slot3'))==manual_bytes,'manual recovery slot untouched')
 await press('读取存档')
 var checkpoint_button=button('第一章结尾检查点');verify(checkpoint_button!=null,'checkpoint reachable through load UI')
 if checkpoint_button:
  checkpoint_button.get_parent().get_parent().ensure_control_visible(checkpoint_button);await frames()
  if not OS.get_environment('AMBER_CHECKPOINT_CAPTURE').is_empty():
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OS.get_environment('AMBER_CHECKPOINT_CAPTURE'))
 await press('第一章结尾检查点');await frames(8);game=current_scene
 verify(game.battle.snapshot()==chapter_one_snapshot and game.battle.state_hash()==chapter_one_hash,'checkpoint restores identical inventory equipment RNG and entire chapter one snapshot')
 verify(app.presentation==chapter_one_story,'checkpoint restores ending reading state')
 await settle();await click(game.hud.chapter_button.get_global_rect().get_center());await press('保存结尾并进入第二章');await frames(8);game=current_scene;await settle()
 verify(app.loadable_slots().filter(func(slot):return app.is_chapter_checkpoint(slot)).size()==1,'repeat same transition reuses verified checkpoint')
 verify(FileAccess.get_file_as_bytes(app.save_path(checkpoints[0]))==checkpoint_bytes,'repeated entry never rewrites checkpoint')
 for point in [Vector2i(3,4),Vector2i(3,2),Vector2i(6,2),Vector2i(8,1)]:
  await click(game.hud.dock.action_nodes.move.get_global_rect().get_center())
  var pixel=game.camera.unproject_position(Vector3(point.x,0,point.y));var before=game.battle.step
  await click(pixel);verify(game.battle.step==before,'first click previews')
  if movie:await frames(30)
  await click(pixel);verify(game.battle.step==before+1,'second click confirms once');await settle()
  verify(game.battle.units[0].pos==point,'actual route destination')
  if point!=Vector2i(8,1):
   await click(game.hud.turn_button.get_global_rect().get_center());await press('确认结束');await settle()
 verify(game.battle.outcome=='victory' and game.battle.units[3].hp>0 and game.battle.units[4].hp>0,'nonlethal reach win via UI')
 var truth=game.battle.state_hash()
 await press('暂停');await press('保存旅程');await press('存档一');await press('暂停');await press('返回主界面');await frames(8)
 verify(current_scene.get_script().resource_path=='res://ui/menu.gd','actual menu return')
 await press('读取存档');await press('存档一');await frames(8);game=current_scene
 verify(game.battle.state_hash()==truth and game.battle.content.id=='white_elm_watchhouse','UI reload exact terminal state')
 if movie:await frames(60)
 print('CHAPTER_TWO_PLAYTHROUGH checks=',checks,' failures=0 step=',game.battle.step,' hp=',game.battle.units[0].hp,' normal_timing=',movie)
 quit()
