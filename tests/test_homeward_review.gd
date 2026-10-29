extends SceneTree
const C=preload('res://logic/content.gd')
const L=preload('res://story/library.gd')
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():call_deferred('run')
func run():
 var app=root.get_node('App')
 var traces=C.normalize(JSON.parse_string(FileAccess.get_file_as_string('res://tests/homeward_routes.json')))
 app.save_root='user://review_'+str(Time.get_ticks_usec())
 app.new_game(L.content(1));var identity=app.presentation.campaign_instance
 check(app.save_slot('slot1').is_empty(),'save campaign identity')
 app.new_game(L.content(1));check(app.presentation.campaign_instance!=identity,'new campaign distinct despite same seed')
 check(app.load_slot('slot1') and app.presentation.campaign_instance==identity,'reload retains identity')
 check(app.session.logic.units.filter(func(u):return u.controller=='ai' and u.role=='raider').size()==3,'three bandits')
 for num in [1,3]:
  app.new_game(L.content(num))
  while not app.next_story().is_empty():app.advance_story(true)
  for c in traces[str(num)]:
   var command=c.duplicate();command.erase('step');check(app.session.submit(command),'legal route')
  while not app.next_story().is_empty():app.advance_story(true)
  var writable=app.save_root
  if num==3:check(app.complete_homeward_checkpoint('homeward_03_finish').is_empty(),'chapter3 completed')
  var blocker=FileAccess.open('user://blocked_destination',FileAccess.WRITE);blocker.store_string('fixture');blocker.close()
  app.save_root='user://blocked_destination/saves'
  var snap=app.session.logic.snapshot();var p=app.presentation.duplicate(true);var session=app.session
  var issue=app.complete_homeward_checkpoint('homeward_04_finish',4) if num==3 else app.complete_homeward_checkpoint('homeward_01_finish')
  check(not issue.is_empty(),'write failure reported')
  check(app.session==session and app.session.logic.snapshot()==snap and app.presentation==p,'write failure no mutation')
  if num==1:check(not app.enter_next_chapter() and app.session==session and app.session.logic.snapshot()==snap,'transition failure preserves session')
  app.save_root=writable
  if num==3:
   root.size=Vector2i(960,540);app.mobile_presentation=true;app.safe_area_override=Rect2i(48,24,864,492)
   change_scene_to_file('res://story/interlude.tscn')
   for i in range(6):await process_frame
   var stage=current_scene;var safe=app.ui_safe_rect()
   check(safe.encloses(stage.box.get_global_rect()),'panel in safe area')
   root.get_texture().get_image().save_png('/tmp/homeward-safe-review.png')
   for node in stage.box.find_children('*','Button',true,false):check(safe.encloses(node.get_global_rect()),'button safe '+node.text)
   stage.advance();
   while stage.player.current().get('op')=='beat':stage.advance()
   stage.pause();check(stage.save_cursor(),'save stage cursor')
   var cursor=stage.player.save();var origin=stage.origin()
   change_scene_to_file('res://story/interlude.tscn');await process_frame;await process_frame
   check(current_scene.origin()==origin and current_scene.player.save()==cursor,'same campaign resumes')
   app.new_game(L.content(3))
   change_scene_to_file('res://story/interlude.tscn');await process_frame;await process_frame
   check(current_scene.origin()!=origin and current_scene.player.save()!=cursor,'fresh campaign ignores stale cursor')
 print('HOMEWARD_REVIEW ',checks,' failures=',failures);quit(1 if failures else 0)
