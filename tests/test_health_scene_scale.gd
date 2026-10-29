extends "res://tests/support/test_case.gd"
func _initialize():call_deferred('run')
func frames():
 for i in range(4):await process_frame
func measure(g,bar):
 var logical=root.get_visible_rect().size;var ratio=minf(float(root.size.x)/logical.x,float(root.size.y)/logical.y)
 var half=bar.backing.texture.get_width()*bar.backing.pixel_size*bar.backing.scale.x/2
 return g.camera.unproject_position(bar.position+g.camera.global_basis.x*half).distance_to(g.camera.unproject_position(bar.position-g.camera.global_basis.x*half))*ratio
func run():
 var app=root.get_node('App');app.mobile_presentation=true;app.health_bar_avoidance=false;app.sfx_enabled=false
 var measurements=[]
 var reserve=preload('res://tests/reserve_art_fixture.gd').content()
 var authored_reserve=reserve.duplicate(true);authored_reserve.id='amber_bridge_reference'
 for data in [preload('res://logic/content.gd').reference_content(),reserve,authored_reserve]:
  app.new_game(data);change_scene_to_file('res://main.tscn');await frames();var g=current_scene
  var snapshot=g.battle.snapshot()
  for size in [Vector2i(1280,800),Vector2i(2400,1080),Vector2i(1600,1200)]:
   root.size=size;await frames()
   for fixed in [false,true]:
    var available=g.scene_view.available()
    check(g.scene_view.set_fixed(fixed)==(not fixed or available),'authored scene admission or custom 3D fallback');await frames()
    check(g.scene_view.active==(fixed and available),'requested mode never forces fixed art on custom map')
    var logical=root.get_visible_rect().size;var ratio=minf(float(size.x)/logical.x,float(size.y)/logical.y)
    var height=g.camera.size if g.camera.keep_aspect==Camera3D.KEEP_HEIGHT else g.camera.size*logical.y/logical.x
    var expected=50.0*ratio*g.scene_view.saved_size/height
    for i in range(g.badges.size()):
     var bar=g.badges[i];bar._process(0)
     check(absf(measure(g,bar)-expected)<0.02,'projected backing exactly base50 times scene scale')
     check(bar.horizontal_offset==0 and bar.position.is_equal_approx(g.badge_position(i)),'default owner anchor and avoidance off')
     var width=measure(g,bar)
     for hp in [0,1,5,10]:
      bar.update_health(hp,10,g.battle.units[i].ally);bar._process(0)
      check(is_equal_approx(measure(g,bar),width),'HP ratio does not alter track width')
      check(bar.fill.visible==(hp>0) and bar.fill.region_rect.size.x==roundi(312.0*hp/10.0),'HP fill correct including empty/full')
     var camera_size=g.camera.size;g.camera.size*=0.8;bar._process(0)
     check(absf(measure(g,bar)/width-1.25)<0.001,'camera zoom scales bar with world actors')
     g.camera.size=camera_size;bar._process(0)
    measurements.append({'physical':[size.x,size.y],'fixed':g.scene_view.active,'bar_px':measure(g,g.badges[0]),'content':data.id})
  check(g.battle.snapshot()==snapshot,'presentation does not alter canonical state')
 var production=FileAccess.get_file_as_string('res://view/unit_health.gd')
 for forbidden in ['get_image(', 'body_width_cache', 'idle_library.gd', 'get_pixel(']:check(not production.contains(forbidden),'no startup texture work '+forbidden)
 print('HEALTH_SCENE_SCALE checks=',checks,' failures=',failures,' measurements=',measurements)
 quit(1 if failures else 0)
