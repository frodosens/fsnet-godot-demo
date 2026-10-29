extends "res://tests/support/test_case.gd"
func _initialize():call_deferred('run')
func frames(n=3):
 for i in range(n):await process_frame
func run():
 var app=root.get_node('App');var C=load('res://logic/content.gd');var d=C.chapter_three_content()
 for size in [Vector2i(1280,800),Vector2i(1024,768),Vector2i(2400,1080)]:
  root.size=size;app.mobile_presentation=size.x==2400;app.new_game(d);app.scene_renderer='auto'
  while not app.next_story().is_empty():app.advance_story(true)
  change_scene_to_file('res://main.tscn');await frames(10);var g=current_scene;g.scene_view.cancel_focus();g.scene_view.pan=Vector2.ZERO;g.scene_view.fit()
  check(g.scene_view.active,'active '+str(size));check(is_equal_approx(g.character_scale,1.25),'same velocity factor');check(g.scene_render_scale>1.1 and g.scene_render_scale<1.14,'render-only calibration')
  var view=root.get_visible_rect().size;var cover=minf(view.x/1280.0,view.y/800.0)
  if app.mobile_presentation:cover=maxf(view.x/1280.0,view.y/800.0)
  var offset=(view-Vector2(1280,800)*cover)*0.5;var maxerr=0.0;var cells=0;var edges=0
  for y in range(9):
   for x in range(10):
    if d.terrain[y][x] in ['W','X']:continue
    cells+=1
    var expected=offset+(Vector2(618.8,120.34128)+Vector2(42.4,29.98104)*x+Vector2(-42.4,29.98104)*y)*cover
    var actual=g.camera.unproject_position(Vector3(x,0,y));maxerr=maxf(maxerr,actual.distance_to(expected));check(actual.distance_to(expected)<0.7,'project '+str(Vector2i(x,y)))
    check(g.mouse_cell(actual)==Vector2i(x,y),'pick '+str(Vector2i(x,y)))
    for delta in [Vector2i.RIGHT,Vector2i.DOWN]:
     var end=Vector2i(x,y)+delta
     if end.x<10 and end.y<9 and d.terrain[end.y][end.x] not in ['W','X']:edges+=1
  check(cells==62 and edges==96,'contract topology 62/96')
  check(g.scene_view.tactical_marks.size()==2,'boundary and objective marker')
  check(g.scene_view.painted_lights.size()==4,'real local lights')
  print('CH3_ART ',size,' projection_maxerr=',maxerr,' size=',g.camera.size,' pixel_size=',g.figures[0].pixel_size,' view=',view)
  check(absf(g.figures[0].pixel_size*99*800.0/g.scene_view.authored_size-90)<0.1,'Mara baseline 90px without speed change')
  var custom=d.duplicate(true);custom.terrain[8]='XGGGGGGGGG';check(load('res://view/authored_scene.gd').profile(custom).is_empty(),'custom geometry rejected')
  var dir=OS.get_environment('CH3_CAPTURE')
  if not dir.is_empty():
   await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(dir+'/chapter3-map-'+str(size.x)+'.png')
  var truth=g.battle.snapshot();g.scene_view.set_fixed(false);check(is_equal_approx(g.scene_render_scale,1.0),'3D reset');g.scene_view.set_fixed(true);check(g.battle.snapshot()==truth,'switch no logic change');check(g.scene_view.tactical_marks.size()==2,'no duplicate overlays')
  # Known actor pair diagnostic verifies background and orientation, not new guard art.
  var fixture=d.duplicate(true);fixture.units[3].id='oren';fixture.units[3].x=3;fixture.units[3].y=6
  fixture.story.characters[3].id='oren';fixture.units[3].name='奥伦（背景测试）'
  var runtime=load('res://logic/runtime.gd').new(fixture)
  check(runtime.apply_command({'kind':'attack','unit':0,'target':3,'step':1}),'legal cutin diagnostic')
  g.cutin.consume(100,runtime.events,runtime.units,fixture);g.cutin.draw_tick(9)
  check(g.cutin.reference_background.visible and g.cutin.reference_background.texture.resource_path.contains('sluice_watchhouse'),'battle background')
  check(g.cutin.actor_left,'own side left')
  if not dir.is_empty():
   await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(dir+'/chapter3-battle-'+str(size.x)+'.png')
  g.cutin.finish()
 print('CHAPTER_THREE_ART checks=',checks,' failures=',failures)
 quit(1 if failures else 0)
