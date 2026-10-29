extends CanvasLayer
# Fallback for admitted map identities without authored battle sprites.
# Shows authoritative damage, never synthesizes combat rules or hero portraits.
const UI=preload("res://ui/style.gd")
var game
var event={}
var elapsed=0.0
var actor_index=-1
var target_index=-1
var label:Label
var strike:Line2D
func _ready():
    label=UI.label("",28,Color("fff0c8"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    label.add_theme_color_override("font_outline_color",Color("241916"));label.add_theme_constant_override("outline_size",4);add_child(label);label.hide()
    strike=Line2D.new();strike.width=3;strike.default_color=Color("ffb85f");add_child(strike);strike.hide()
func active():return not event.is_empty()
func start(item):
    clear()
    if item.get("kind")!="attack":return false
    var art=preload("res://view/generic_map_art.gd")
    if not art.declared(item.get("actor","")) and not art.declared(item.get("target","")):return false
    for i in game.battle.units.size():
        if game.battle.units[i].id==item.get("actor"):actor_index=i
        if game.battle.units[i].id==item.get("target"):target_index=i
    if actor_index<0 or target_index<0:return false
    event=item.duplicate(true);elapsed=0
    label.text=game.battle.units[actor_index].name+" → "+game.battle.units[target_index].name+"  −"+str(item.get("damage",0))
    label.show();update_positions();return true
func update_positions():
    var a=game.camera.unproject_position(game.figures[actor_index].position+Vector3(0,.6,0))
    var b=game.camera.unproject_position(game.badge_position(target_index))
    label.position=b+Vector2(-label.size.x*.5,-32-(0 if App.reduced_motion else 18*sin(elapsed/.75*PI)))
    strike.points=PackedVector2Array([a,b]);strike.visible=not App.reduced_motion and elapsed<.18
func _process(delta):
    if not active():return
    elapsed+=maxf(delta,0)
    if elapsed>=.75:clear();return
    update_positions();label.modulate.a=clampf((.75-elapsed)/.18,0,1)
func clear():
    event={};elapsed=0;actor_index=-1;target_index=-1
    if label:label.hide();label.modulate.a=1
    if strike:strike.hide()
