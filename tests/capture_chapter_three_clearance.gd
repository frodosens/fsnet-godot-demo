extends SceneTree
func _initialize():call_deferred('run')
func run():
 var app=root.get_node('App');app.mobile_presentation=false;app.scene_renderer='auto';root.size=Vector2i(1280,800);app.new_game(load('res://logic/content.gd').chapter_three_content())
 while not app.next_story().is_empty():app.advance_story(true)
 change_scene_to_file('res://main.tscn')
 for i in range(8):await process_frame
 var g=current_scene;var actor=4 if OS.get_environment('CH3_PROBE_ACTOR')=='vera' else (3 if OS.get_environment('CH3_PROBE_ACTOR')=='rodd' else 0);var actor_id=g.battle.units[actor].id;var truth=g.battle.snapshot();var sheet=Image.create(8*150,8*160,false,Image.FORMAT_RGBA8);sheet.fill(Color('#17262d'));var n=0
 var title=Label.new();title.text='站位探针：仅移动角色显示节点，非实际指令录像';title.position=Vector2(300,110);g.hud.root.add_child(title)
 for i in range(g.figures.size()):g.figures[i].visible=i==actor;g.badges[i].visible=false
 g.hud.dock.hide()
 var coords=[]
 for y in range(9):
  for x in range(10):
   if g.battle.content.terrain[y][x] in ['W','X']:continue
   coords.append(Vector2i(x,y))
 for p in coords:
  g.figures[actor].position=Vector3(p.x,0,p.y);g.scene_view.sync_shadows();g.selection_ring.hide()
  title.text='站位探针 '+str(p)+' · 未改变规则坐标；显示探针，不是移动指令'
  await process_frame;await RenderingServer.frame_post_draw
  var image=root.get_texture().get_image();var center=g.camera.unproject_position(g.figures[actor].position)
  var region=Rect2i(Vector2i(center)-Vector2i(75,135),Vector2i(150,160));sheet.blit_rect(image,region,Vector2i(n%8*150,n/8*160));n+=1
  if p==Vector2i(8,1):image.save_png('/workspace/chapter3-captures/chapter3-'+actor_id+'-goal-probe.png')
 sheet.save_png('/workspace/chapter3-captures/chapter3-'+actor_id+'-clearance-probes.png')
 assert(g.battle.snapshot()==truth)
 print('CH3_CLEARANCE_PROBES ',n,' row-major walkable coordinates; snapshot unchanged')
 quit()
