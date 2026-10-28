extends SceneTree
var checks=0
var failures=0
func check(ok,label):
 checks+=1
 if not ok:failures+=1;printerr('FAIL ',label)
func _initialize():call_deferred('run')
func frames(n=3):
 for i in range(n):await process_frame
func run():
 var art=load('res://view/chapter_guard_art.gd');var C=load('res://logic/content.gd');var R=load('res://logic/runtime.gd');var app=root.get_node('App')
 var m=JSON.parse_string(FileAccess.get_file_as_string(art.ROOT+'map_contract.json'));var b=JSON.parse_string(FileAccess.get_file_as_string(art.ROOT+'battle_contract.json'))
 check(art.decode(m,b).size()==2,'complete assets')
 for bad in [null,[],true,7,'bad']:
  check(art.decode(bad,b).is_empty() and art.decode(m,bad).is_empty(),'top-level failclosed')
  var badmap=m.duplicate(true);badmap.characters.vera.map_static=bad;check(art.decode(badmap,b).is_empty(),'nested map malformed')
  var badbattle=b.duplicate(true);badbattle.characters.rodd.defender=bad;check(art.decode(m,badbattle).is_empty(),'nested defender malformed')
 for id in art.IDS:
  var a=art.profile(id);check(not a.is_empty(),'identity '+id);check(a.portrait_path.contains('/'+id+'/'),'portrait identity')
  for dir in art.DIRECTIONS:check(a.map[dir].get_size()==Vector2(128,128) and a.map[dir].resource_path.contains('/'+id+'/'),'canonical128 identity')
 for config in [[Vector2i(1280,800),"auto"],[Vector2i(2400,1080),"auto"],[Vector2i(1280,800),"3d"],[Vector2i(960,600),"3d"]]:
  var size=config[0]
  root.size=size;app.mobile_presentation=size.x>1280;app.new_game(C.chapter_three_content());app.scene_renderer=config[1]
  while not app.next_story().is_empty():app.advance_story(true)
  change_scene_to_file('res://main.tscn');await frames(8);var g=current_scene;var snapshot=g.battle.snapshot()
  check(g.figures[3].texture.resource_path.contains('/rodd/') and g.figures[4].texture.resource_path.contains('/vera/'),'no legacy figure impersonation')
  for dir in art.DIRECTIONS:
   g.facing.vera=dir
   var neutral=g.base_directional_idle_texture(4,dir);check(neutral.get_size()==Vector2(128,128),'neutral128')
   for tick in range(40):
    g.apply_map_motion_texture(4,dir,(tick+.5)/40.0)
    check(g.figures[4].texture.resource_path.ends_with('_walk_%02d.png'%int(tick/5)),'weighted motion')
    check(g.figures[4].flip_h==dir.ends_with('right'),'direction mirror')
    var foot=g.figure_texture_pixel_position(4,Vector2(64,120));check(foot.distance_to(g.figures[4].position)<0.0001,'root stable')
   g.apply_map_motion_texture(4,dir,1.0);check(g.figures[4].texture.resource_path.ends_with('00.png'),'grid cycle')
   g.motion.settle('vera',4);check(not g.figures[4].flip_h and g.figures[4].texture==neutral,'idle resets flip')
   g.apply_map_motion_texture(3,dir,.5);check(g.figures[3].texture==g.base_directional_idle_texture(3,dir) and not g.figures[3].flip_h,'Rodd static')
  g.vera_motion_enabled=false;g.apply_map_motion_texture(4,'front_right',.3);check(not g.figures[4].flip_h and g.figures[4].texture==g.base_directional_idle_texture(4,'front_right'),'disabled canonical fallback');g.vera_motion_enabled=true
  var cut=g.cutin
  for pair in [['mara','rodd'],['rodd','mara'],['finn','vera'],['vera','finn'],['neri','rodd'],['rodd','neri'],['elsbet','vera']]:
   for left in [true,false]:
    var event={'kind':'attack','actor':pair[0],'target':pair[1],'damage':2,'hp':5,'max_hp':9,'actor_hp':8,'actor_max_hp':12,'ability':'ember' if pair[0]=='neri' else 'attack','actor_left':left}
    cut.finish();cut.pending_events=[event];cut.play_next()
    for tick in range(24):
     cut.draw_tick(tick);check(cut.attacker.texture!=null and cut.defender.texture!=null,'all attack hit recovery frames')
     check(cut.actor_left==left,'side mapping preserved')
    cut.draw_tick(cut.hit_tick())
    if cut.is_melee():check(cut.weapon_screen_point().distance_to(cut.hurt_screen_point())<0.01,'melee contact')
    else:check(cut.projectile_screen_point().distance_to(cut.hurt_screen_point())<0.01,'arrow/magic impact')
    if pair[0]=='rodd':check(absf(cut.attacker.position.y-205)<0.01,'Rodd feet floor')
    cut.finish();check(not cut.active and not cut.projectile.visible,'skip finalizes presentation')
  check(g.battle.snapshot()==snapshot,'render tests no rule mutation')
  var dir=OS.get_environment('CH3_GUARD_CAPTURE')
  if not dir.is_empty():
   g.refresh_map_sequence_art();await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(dir+'/chapter3-guards-'+str(size.x)+'-'+str(config[1])+'.png')
 print('CHAPTER_GUARDS checks=',checks,' failures=',failures)
 quit(1 if failures else 0)
