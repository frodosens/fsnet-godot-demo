extends SceneTree
const C=preload('res://logic/content.gd')
const Art=preload('res://view/generic_map_art.gd')
var checks=0
func check(ok,label):
 checks+=1
 if not ok:printerr('FAIL ',label);quit(1)
 assert(ok,label)
func _initialize():call_deferred('run')
func run():
 var app=root.get_node('App')
 for size in [Vector2i(1280,800),Vector2i(2400,1080)]:
  root.size=size;app.mobile_presentation=size.x>2000;check(app.new_game(preload('res://story/library.gd').content(1)),'real chapter')
  change_scene_to_file('res://main.tscn');await process_frame;await process_frame
  var g=current_scene;g.refresh()
  for i in range(2,5):
   var id=g.battle.units[i].id
   check(Art.canonical_id(id)=='generic_bandit_01','bandit identity')
   check(not Art.profile(id).static_fallback,'valid gait')
   check(g.hero_refresh_libraries.has(id),'actual bound instance')
   check(preload('res://ui/style.gd').framed_portrait(id)==null,'no hero portrait')
   check(g.figures[i].texture.get_width()==160,'real canonical texture')
  check(g.hero_refresh_libraries.ch01_bandit_a!=g.hero_refresh_libraries.ch01_bandit_b,'independent playback')
  while not app.next_story().is_empty():app.advance_story(true)
  if DisplayServer.get_name()!='headless':
   await process_frame;root.get_texture().get_image().save_png('/tmp/homeward-three-bandits-'+str(size.x)+'.png')
  for c in C.normalize(JSON.parse_string(FileAccess.get_file_as_string('res://tests/homeward_routes.json')))['1']:
   var command=c.duplicate();command.erase('step');check(app.session.submit(command),'legal chapter command')
   await process_frame;g.refresh();g.skip_presentation();await process_frame
   for i in range(2,5):
    check(g.figures[i].visible==(g.battle.units[i].hp>0),'death visibility follows own HP')
  check(g.battle.outcome=='victory','two heroes win against real bandit bindings')
 print('HOMEWARD_BANDITS checks=',checks,' failures=0');quit()
