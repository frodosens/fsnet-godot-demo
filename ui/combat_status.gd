extends Control
const ART="res://assets/ui/combat_reference/"
var owner_cutin
var labels={}
var bars={}
var portraits={}
var title_label
var quick
var manifest=JSON.parse_string(FileAccess.get_file_as_string(ART+"manifest.json"))
func rect(key):
    var a=manifest.layout_rects_xywh[key];return Rect2(a[0],a[1],a[2],a[3])
func picture(path,area):
    var node=TextureRect.new();node.texture=load(path);node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;node.position=area.position;node.size=area.size;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(node);return node
func text(value,area,font=28):
    var node=Label.new();node.text=value;node.position=area.position;node.size=area.size;node.add_theme_font_size_override("font_size",font);node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.clip_text=true;add_child(node);return node
func control(kind,caption,callback):
    var button=Button.new();button.position=rect(kind).position;button.size=rect(kind).size;button.text=caption;button.add_theme_font_size_override("font_size",26);button.add_theme_constant_override("icon_max_width",28)
    for state in ["normal","hover","focus","pressed"]:
        var skin=StyleBoxTexture.new();skin.texture=load(ART+kind+"-"+({"hover":"focused","focus":"focused"}.get(state,state))+".png")
        for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:skin.set_texture_margin(side,14)
        button.add_theme_stylebox_override(state,skin)
    button.pressed.connect(callback);add_child(button);return button
func setup(cutin):
    owner_cutin=cutin;mouse_filter=Control.MOUSE_FILTER_IGNORE
    for side in ["left","right"]:
        picture(ART+"status_"+side+".png",rect("status_"+side))
        var p=manifest.portrait_reserved_rects_xyxy[side]
        portraits[side]=picture("res://assets/portraits/mara.png",Rect2(p[0],p[1],p[2]-p[0],p[3]-p[1]))
        var x=225 if side=="left" else 990
        labels[side]=text("",Rect2(x,778,365,42),30)
        picture(ART+"hp_track.png",rect("hp_"+side))
        var bar=TextureProgressBar.new();bar.texture_progress=load(ART+"hp_fill_"+("ally" if side=="left" else "enemy")+".png");bar.position=rect("hp_fill_"+side).position;bar.size=rect("hp_fill_"+side).size;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bar);bars[side]=bar
        labels[side+"_hp"]=text("",Rect2(x+40,866,285,34),27)
    picture(ART+"move_title.png",rect("move_title"));picture(ART+"action-sword.png",Rect2(566,74,48,48))
    title_label=text("",Rect2(626,78,390,46),30)
    quick=control("speed","×1",func():cutin.speed=3.0 if cutin.speed==1.0 else 1.0;quick.text="×"+str(int(cutin.speed)))
    quick.icon=load(ART+"speed-fastforward.png");quick.expand_icon=true
    var skip=control("skip","跳过",cutin.finish);skip.icon=load(ART+"skip-next.png");skip.expand_icon=true;skip.tooltip_text="空格 / Esc：跳过演出"
func show_event(event):
    var data=event.get("presentation",{})
    for side in ["left","right"]:
        var actor=(side=="left")==event.get("actor_left",true);var id=event.get("actor_profile",event.actor) if actor else event.get("target_profile",event.target)
        var path=preload("res://view/reserve_art.gd").portrait_path(id)
        # Screen-side presentation only; reset explicitly for every reused event.
        portraits[side].flip_h=side=="right"
        portraits[side].texture=load(path) if ResourceLoader.exists(path) else null
        bars[side].texture_progress=load(ART+"hp_fill_"+("ally" if data.get("actor_ally" if actor else "target_ally",false) else "enemy")+".png")
        labels[side].text=data.get("actor_name" if actor else "target_name",id)
    update_health(event,false)
func update_health(event,hit):
    var data=event.get("presentation",{})
    for side in ["left","right"]:
        var actor=(side=="left")==event.get("actor_left",true);var maximum=data.get("actor_max_hp" if actor else "target_max_hp",0)
        var value=data.get(("actor_after" if hit else "actor_hp") if actor else ("target_after" if hit else "target_before"),0)
        bars[side].max_value=maxi(1,maximum);bars[side].value=value
        labels[side+"_hp"].text="HP  %d / %d"%[value,maximum] if maximum>0 else "HP  —"
