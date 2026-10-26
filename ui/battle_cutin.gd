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
func _ready():
    layer=30
    surface=Control.new();surface.theme=UI.make_theme();surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(surface)
    var shade=ColorRect.new();shade.color=Color(0.10,0.09,0.08,0.88);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);surface.add_child(shade)
    var stage=PanelContainer.new();stage.position=Vector2(100,130);stage.size=Vector2(1080,480);surface.add_child(stage)
    var floor_panel=ColorRect.new();floor_panel.color=Color("a98c61");floor_panel.position=Vector2(120,495);floor_panel.size=Vector2(1040,90);surface.add_child(floor_panel)
    title=UI.label("玛拉 · 突刺",26);title.position=Vector2(145,155);surface.add_child(title)
    attacker=figure();defender=figure()
    damage_label=UI.label("",42,Color("8a352b"));damage_label.position=Vector2(850,275);surface.add_child(damage_label)
    var quick=UI.button("加速 ×1",func():speed=3.0 if speed==1.0 else 1.0)
    quick.position=Vector2(850,630);quick.pressed.connect(func():quick.text="加速 ×"+str(int(speed)));surface.add_child(quick)
    var skip=UI.button("跳过 · 空格",finish);skip.position=Vector2(1000,630);surface.add_child(skip)
    var note=UI.label("战斗结果已结算；此处仅播放演出。",16,Color("eadbbd"));note.position=Vector2(120,635);surface.add_child(note)
    surface.hide()
func figure():
    var image=TextureRect.new();image.size=Vector2(384,320);image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;surface.add_child(image);return image
func consume(step,events):
    if step==last_seen_step:return
    last_seen_step=step
    for item in events:
        if item.kind=="attack" and item.actor=="mara" and item.target=="oren":
            event=item;elapsed=0.0;active=true;surface.show();draw_tick(0);return
func draw_tick(tick):
    attacker.texture=load("res://assets/battle/mara/"+MARA[TIMELINE[clampi(tick,0,23)]]+".png")
    var defend=0 if tick<8 else (1 if tick<10 else (2 if tick<16 else 3))
    defender.texture=load("res://assets/battle/oren/"+OREN[defend]+".png")
    var offset=clampf((tick-6)/4.0,0,1)*260.0 if tick<18 else clampf((24-tick)/6.0,0,1)*260.0
    attacker.position=Vector2(180+offset,205);defender.position=Vector2(700,205)
    damage_label.text="−"+str(event.get("damage",0)) if tick>=10 else ""
func _process(delta):
    if not active:return
    elapsed+=delta*speed
    var tick=int(elapsed*12)
    if tick>=24:finish()
    else:draw_tick(tick)
func finish():active=false;surface.hide()
func _input(input):
    if active and input is InputEventKey and input.pressed and not input.echo and input.physical_keycode in [KEY_SPACE,KEY_ESCAPE,KEY_ENTER]:
        finish();get_viewport().set_input_as_handled()
