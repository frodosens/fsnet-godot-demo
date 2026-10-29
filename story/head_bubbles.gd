extends Control
var game
var icons={}
var textures={}
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 z_index=5
 for id in preload('res://story/player.gd').EMOTES:textures[id]=load('res://assets/ui/story_emotes_v1/emote_'+id+'.png')
func _process(_delta):
 if not game or not is_instance_valid(game.hud):return
 var active=game.battle.content.id.begins_with('homeward_') and game.hud.story_panel.visible and not is_instance_valid(game.hud.modal)
 for icon in icons.values():icon.hide()
 if not active:return
 for actor in App.homeward_player.bubbles:
  var index=-1
  for i in range(game.battle.units.size()):
   if game.battle.units[i].id==actor:index=i;break
  if index<0 or game.battle.units[index].hp<=0:continue
  var world=game.badge_position(index)
  if game.camera.is_position_behind(world):continue
  var point=game.camera.unproject_position(world)
  var bounds=get_viewport_rect().grow(-42)
  if not bounds.has_point(point):continue
  if not icons.has(actor):
   var icon=TextureRect.new();icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.size=Vector2(36,36);add_child(icon);icons[actor]=icon
  var icon=icons[actor];icon.texture=textures[App.homeward_player.bubbles[actor]]
  # Tail is below the panel; keep it above meter/selection marker, never cover HUD.
  var chosen=Rect2(point-Vector2(18,61),Vector2(36,36))
  for dx in [0.0,48.0,-48.0,84.0,-84.0]:
   var trial=Rect2(point+Vector2(dx-18,-61),Vector2(36,36));var blocked=false
   if not get_viewport_rect().grow(-8).encloses(trial):continue
   for j in range(game.battle.units.size()):
    if j==index or game.battle.units[j].hp<=0:continue
    var head=game.camera.unproject_position(game.figure_pixel_position(j,Vector2(48,18)))
    var body=Rect2(head-Vector2(28,10),Vector2(56,64))
    if trial.intersects(body):blocked=true;break
   if not blocked:chosen=trial;break
  icon.position=chosen.position;icon.show()
