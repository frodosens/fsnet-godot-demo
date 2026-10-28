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
 var app=root.get_node('App');app.save_root='user://ch3_scene_'+str(Time.get_ticks_usec());app.scene_renderer='auto'
 var C=load('res://logic/content.gd')
 for viewport in [Vector2i(1280,800),Vector2i(960,600)]:
  root.size=viewport;app.new_game(C.chapter_two_content())
  for p in [Vector2i(3,4),Vector2i(3,2),Vector2i(6,2),Vector2i(8,1)]:
   check(app.session.submit({'kind':'move','unit':0,'x':p.x,'y':p.y}),'natural chapter2 approach')
   if p!=Vector2i(8,1):check(app.session.submit({'kind':'end_turn'}),'AI')
  change_scene_to_file('res://main.tscn');await frames(8);current_scene.skip_presentation();await frames()
  check(not current_scene.hud.chapter_button.visible,'chapter3 hidden until ending read')
  await click(button('跳过本段',current_scene.hud.story_panel))
  check(current_scene.hud.chapter_button.visible and current_scene.hud.chapter_button.text=='前往第三章','correct chapter label')
  await click(current_scene.hud.chapter_button)
  await click(button('返回',current_scene.hud.modal))
  check(app.session.logic.content.id=='white_elm_watchhouse','cancel preserves chapter2')
  await click(current_scene.hud.chapter_button)
  await click(button('保存结尾并进入第三章',current_scene.hud.modal));await frames(8)
  var game=current_scene
  check(game.battle.content.id=='mill_receipts','real click chapter3 entry')
  check(not game.scene_view.active,'no unapproved painted background')
  check(game.hud.story_panel.visible and not game.hud.dock.visible,'intro modal')
  await click(button('下一句',game.hud.story_panel))
  await click(button('暂停 / 保存',game.hud.story_panel))
  await click(button('继续战斗',game.hud.modal))
  await click(button('跳过本段',game.hud.story_panel))
  check(not game.hud.story_panel.visible,'story dismissed')
  check(game.battle.units.size()==5 and game.battle.units[3].id=='rodd','new guard identity no old identity replacement')
  check(game.mouse_cell(game.camera.unproject_position(Vector3(8,0,1)))==Vector2i(8,1),'goal projection picking')
  var truth=game.battle.snapshot();game.hud.choose_action('move');game.update_move_preview(Vector2i(6,7))
  check(game.preview_path.size()==4,'authoritative legal preview')
  game.clear_move_preview();check(game.battle.snapshot()==truth,'preview cancel unchanged')
  check(app.save_slot('auto').is_empty(),'actual scene autosave')
  var slot=app.loadable_slots().filter(func(s):return s.begins_with('chapter2_end_'))[0]
  check(app.inspect_slot(slot).error.is_empty(),'load menu checkpoint inspect')
 print('CHAPTER_THREE_SCENE checks=',checks,' failures=',failures)
 quit(1 if failures else 0)
