extends "res://tests/support/test_case.gd"
const C=preload("res://logic/content.gd")
func _initialize():call_deferred('run')
func frames(n=4):
 for i in range(n):await process_frame
func run():
 var app=root.get_node('App');app.save_root='user://homeward_test_'+str(Time.get_ticks_usec())
 var traces=C.normalize(JSON.parse_string(FileAccess.get_file_as_string('res://tests/homeward_routes.json')))
 for size in [Vector2i(1280,800),Vector2i(2400,1080)]:
  root.size=size;check(app.new_game(preload('res://story/library.gd').content(1)),'start two-person campaign')
  for num in range(1,4):
   change_scene_to_file('res://main.tscn');await frames(8)
   var g=current_scene
   check(g.scene_view.active,'new ID retains authored background')
   check(g.battle.units.filter(func(u):return u.controller=='player').size()==(2 if num<3 else 3),'deployed party')
   var hash=g.battle.state_hash()
   for i in range(4):app.advance_story(false)
   check(app.save_slot('slot1').is_empty(),'cue saved')
   var cursor=app.presentation.duplicate(true)
   check(app.load_slot('slot1') and app.presentation==cursor,'cue reload exact')
   change_scene_to_file('res://main.tscn');await frames(8);g=current_scene
   check(g.battle.state_hash()==hash,'reading cannot mutate Lua')
   while not app.next_story().is_empty():app.advance_story(true)
   for c in traces[str(num)]:
    var command=c.duplicate();command.erase('step')
    check(app.session.submit(command),'real session command')
    await frames(2);g.skip_presentation();await frames(2)
   check(g.battle.outcome=='victory','actual scene victory')
   while not app.next_story().is_empty():app.advance_story(true)
   check(app.next_chapter_ready(),'ending ready')
   var snapshot=g.battle.snapshot()
   app.session.online=true;check(not app.enter_next_chapter() and g.battle.snapshot()==snapshot,'online local swap blocked');app.session.online=false
   check(app.enter_next_chapter(),'checkpoint-backed transition')
   await frames(3)
   if num==2:
    check(current_scene.get_script().resource_path=='res://story/interlude.gd','inn is independent scene')
    current_scene.skip();current_scene.finish();await frames(6)
  await frames(6)
  check(current_scene.get_script().resource_path=='res://story/interlude.gd','independent nonbattle scene')
  var stage=current_scene;stage.cursor_path='user://homeward_test_cursor_'+str(size.x)+'.json'
  var battle_hash=app.session.logic.state_hash();var xp=app.session.logic.campaign_state()
  stage.pause();var cursor=stage.player.save();await frames(5);check(stage.player.save()==cursor,'interlude pause');stage.pause()
  stage.skip();stage.finish();stage.finish()
  check(app.homeward_event_done('homeward_04_finish'),'chapter4 finish once')
  check(app.loadable_slots().any(func(slot):return slot.begins_with('homeward4_end_')),'durable fourth chapter checkpoint')
  check(app.session.logic.campaign_state()==xp,'no fake victory XP')
  check(stage.save_cursor(),'interlude cursor persistence')
  if not DisplayServer.get_name()=='headless':
   await process_frame;root.get_texture().get_image().save_png('/tmp/homeward-interlude-'+str(size.x)+'.png')
 print('HOMEWARD_SCENE ',checks,' checks failures=',failures);quit(1 if failures else 0)
