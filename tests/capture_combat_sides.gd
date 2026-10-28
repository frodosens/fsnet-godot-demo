extends SceneTree
var app
var game
var seen_left=false
var seen_right=false
var captured={}
func _initialize():call_deferred('run')
func frames(n):
 for i in range(n):await process_frame
func wait_presentation():
 var count=0
 while game.presentation_active() and count<1800:
  var c=game.cutin
  if c.active:
   if c.actor_left:seen_left=true
   else:seen_right=true
   var key='left' if c.actor_left else 'right'
   if c.elapsed>=c.hit_tick()*c.tick_seconds and not captured.has(key):
    captured[key]=true
    assert(c.combat_status.labels.left.text=='玛拉')
    if not OS.get_environment('AMBER_SIDES_CAPTURE_DIR').is_empty():
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(OS.get_environment('AMBER_SIDES_CAPTURE_DIR')+'/'+key+'.png')
  count+=1;await process_frame
 assert(count<1800)
func run():
 app=root.get_node('App');app.scene_renderer='auto'
 var data=preload('res://logic/content.gd').reference_content()
 # Legal adjacent-placement fixture, not a claimed unmodified chapter playthrough.
 data.units[3].x=4;data.units[3].y=6;data.units[3].hp=100
 assert(app.new_game(data))
 change_scene_to_file('res://main.tscn');await frames(12);game=current_scene
 while not app.next_story().is_empty():app.advance_story(true)
 game.refresh();await frames(30)
 assert(app.session.submit({'kind':'attack','unit':0,'target':3}))
 game.battle=app.session.logic;game.refresh();await wait_presentation();await frames(30)
 assert(app.session.submit({'kind':'end_turn'}))
 game.battle=app.session.logic;game.refresh();await wait_presentation();await frames(30)
 assert(seen_left and seen_right)
 print('COMBAT_SIDES_ACTUAL_GAME left_initiation=',seen_left,' right_initiation=',seen_right,' normal_simulation=true step=',game.battle.step)
 quit()
