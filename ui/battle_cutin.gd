extends CanvasLayer
# Presentation only: settled events, no command submission or state mutation.
const UI=preload("res://ui/style.gd")
const MARA=["00_idle","01_anticipation","02_dash","03_thrust","04_follow_through","05_recovery","06_return_step","07_settle_guard"]
const OREN=["00_idle","01_brace","02_hit","03_recover"]
const TIMELINE=[0,0,1,1,1,1,2,2,2,2,3,3,3,4,4,4,5,5,5,6,6,6,7,7]
var active=false
var elapsed=0.0
var speed=1.0
var event={}
var surface
var attacker
var defender
var damage_label
var title
var last_seen_step=-1
var actor_sets={}
var fx={}
var projectile
var tick_seconds=1.0/12.0
var release_tick=10
func _ready():
    layer=30
    surface=Control.new();surface.theme=UI.make_theme();surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(surface)
    var shade=ColorRect.new();shade.color=Color(0.10,0.09,0.08,0.88);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.add_child(shade)
    var stage=PanelContainer.new();stage.position=Vector2(100,130);stage.size=Vector2(1080,480);surface.add_child(stage)
    var floor_panel=ColorRect.new();floor_panel.color=Color("59624b");floor_panel.position=Vector2(120,495);floor_panel.size=Vector2(1040,90);surface.add_child(floor_panel)
    title=UI.label("玛拉 · 突刺",26);title.position=Vector2(145,155);surface.add_child(title)
    attacker=figure();defender=figure()
    projectile=TextureRect.new();projectile.size=Vector2(128,96);projectile.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;projectile.mouse_filter=Control.MOUSE_FILTER_IGNORE;surface.add_child(projectile)
    var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/battle/ranged_magic/manifest.json"))
    for id in manifest.characters:
        var data=manifest.characters[id];var textures=[]
        for frame in data.frames:textures.append(load("res://assets/battle/ranged_magic/"+frame.path))
        actor_sets[id]={"textures":textures,"timeline":data.timeline_24ticks,"tick_seconds":data.tick_ms/1000.0,"release":int(data.release_tick)}
    for effect in manifest.effects:fx[effect.state]=load("res://assets/battle/ranged_magic/"+effect.path)
    damage_label=UI.label("",42,Color("d5a18b"));damage_label.position=Vector2(850,275);surface.add_child(damage_label)
    var quick=UI.button("加速 ×1",func():speed=3.0 if speed==1.0 else 1.0)
    quick.position=Vector2(850,630);quick.pressed.connect(func():quick.text="加速 ×"+str(int(speed)));surface.add_child(quick)
    var skip=UI.button("跳过 · 空格",finish);skip.position=Vector2(1000,630);surface.add_child(skip)
    var note=UI.label("战斗结果已结算；此处仅播放演出。",16,Color("adb3a6"));note.position=Vector2(120,635);surface.add_child(note)
    surface.hide()
func figure():
    var image=TextureRect.new();image.size=Vector2(384,320);image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;surface.add_child(image);return image
func consume(step,events):
    if step==last_seen_step:return
    finish();last_seen_step=step
    for item in events:
        if item.get("kind")!="attack" or item.get("target")!="oren":continue
        if item.actor!="mara" and not actor_sets.has(item.actor):continue
        if item.actor=="neri" and item.get("ability") not in ["ember","focus_bolt"]:continue
        event=item;elapsed=0.0;active=true
        tick_seconds=1.0/12.0 if item.actor=="mara" else actor_sets[item.actor].tick_seconds
        release_tick=10 if item.actor=="mara" else actor_sets[item.actor].release
        title.text={"mara":"玛拉 · 突刺","finn":"芬恩 · 放箭","neri":"奈莉 · 施法"}[item.actor]
        surface.show();draw_tick(0);return
func draw_tick(tick):
    tick=clampi(tick,0,23)
    var melee=event.get("actor")=="mara"
    if melee:attacker.texture=load("res://assets/battle/mara/"+MARA[TIMELINE[tick]]+".png")
    else:
        var data=actor_sets[event.actor];attacker.texture=data.textures[int(data.timeline[tick])]
    var hit_tick=release_tick if melee else release_tick+4
    var defend=0 if tick<release_tick-2 else (1 if tick<hit_tick else (2 if tick<hit_tick+4 else 3))
    if event.get("hp",1)==0 and tick>=hit_tick:defend=2
    defender.texture=load("res://assets/battle/oren/"+OREN[defend]+".png")
    defender.modulate.a=clampf(1.0-(tick-hit_tick-2)/5.0,0,1) if event.get("hp",1)==0 and tick>=hit_tick else 1.0
    var offset=0.0
    if melee:offset=clampf((tick-6)/4.0,0,1)*260.0 if tick<18 else clampf((24-tick)/6.0,0,1)*260.0
    attacker.position=Vector2(180+offset,205);defender.position=Vector2(700,205)
    damage_label.text="−"+str(event.get("damage",0)) if tick>=hit_tick else ""
    projectile.hide()
    if not melee:
        var magic=event.actor=="neri"
        var origin=Vector2(480 if magic else 456,365);var impact=Vector2(890,365)
        if magic and tick>=5 and tick<release_tick:
            projectile.texture=fx.gather if tick<8 else fx.charge;projectile.position=origin-Vector2(64,65);projectile.show()
        elif tick>=release_tick and tick<hit_tick:
            projectile.texture=fx.bolt if magic else fx.arrow
            projectile.position=origin.lerp(impact,(tick-release_tick)/4.0)-Vector2(64,48);projectile.show()
        elif magic and tick>=hit_tick and tick<22:
            projectile.texture=fx.impact if tick<hit_tick+3 else fx.dissipate;projectile.position=impact-Vector2(64,48);projectile.show()
func _process(delta):
    if not active:return
    elapsed+=delta*speed
    var tick=int(elapsed/tick_seconds)
    if tick>=24:finish()
    else:draw_tick(tick)
func finish():active=false;surface.hide()
func _input(input):
    if active and input is InputEventKey and input.pressed and not input.echo and input.physical_keycode in [KEY_SPACE,KEY_ESCAPE,KEY_ENTER]:
        finish();get_viewport().set_input_as_handled()
