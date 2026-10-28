extends Control
# Original portrait crops only. No rule state or command submission lives here.
const UI=preload("res://ui/style.gd")
const ART="res://assets/ui/party_eye_v2/"
const EYES={"rodd":Rect2(215,110,170,70),"mara":Rect2(170,130,220,96),"finn":Rect2(180,128,230,100),"neri":Rect2(195,138,220,100),"tessa":Rect2(180,132,220,96),"oren":Rect2(180,120,230,96),"bram":Rect2(195,120,230,96),"adela":Rect2(180,130,220,96),"elsbet":Rect2(205,140,220,96)}
var hud
var scroll:ScrollContainer
var column:VBoxContainer
var rows={}
var identities=[]
var crops={}
var pointer=-2
var pressed_index=-1
var pressed_step=-1
var start=Vector2.ZERO
var scroll_start=0
var dragged=false
var synthetic_until=0
var textures={}
var empty_skin=StyleBoxEmpty.new()
var gray_shader:Shader
func _ready():
    mouse_filter=Control.MOUSE_FILTER_STOP
    for key in ["frame_normal","frame_selected","frame_moved","selected_notch","icon_action","icon_move","icon_done"]:textures[key]=load(ART+key+".png")
    gray_shader=Shader.new();gray_shader.code="shader_type canvas_item; uniform float faded=0.0; void fragment(){vec4 c=texture(TEXTURE,UV)*COLOR;float g=dot(c.rgb,vec3(0.299,0.587,0.114));COLOR=vec4(mix(c.rgb,vec3(g)*0.75,faded),c.a);}"
    scroll=ScrollContainer.new();scroll.mouse_filter=Control.MOUSE_FILTER_IGNORE;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(scroll)
    column=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",4);scroll.add_child(column)
func eye_crop(id):
    if crops.has(id):return crops[id]
    var path=preload("res://view/reserve_art.gd").portrait_path(id)
    if not ResourceLoader.exists(path):return null
    var texture=load(path)
    if not texture is Texture2D:return null
    # Unknown Mod portraits retain identity; conservative central upper-face crop.
    var region=EYES.get(id,Rect2(texture.get_width()*0.3,texture.get_height()*0.25,texture.get_width()*0.45,texture.get_height()*0.2))
    var atlas=AtlasTexture.new();atlas.atlas=texture;atlas.region=region.intersection(Rect2(Vector2.ZERO,texture.get_size()));atlas.filter_clip=true
    crops[id]=atlas;return atlas
func rebuild(members):
    cancel_pointer()
    for child in column.get_children():column.remove_child(child);child.queue_free()
    rows.clear();identities=members.duplicate()
    for member in members:
        var i=member[0];var unit=hud.game.battle.units[i]
        var button=Button.new();button.name="Party_"+unit.id;button.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.focus_mode=Control.FOCUS_ALL
        button.pressed.connect(activate.bind(i));column.add_child(button)
        var eye=TextureRect.new();eye.texture=eye_crop(unit.id);eye.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;eye.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;eye.mouse_filter=Control.MOUSE_FILTER_IGNORE
        eye.material=ShaderMaterial.new();eye.material.shader=gray_shader;button.add_child(eye)
        var frame=TextureRect.new();frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(frame)
        var notch=TextureRect.new();notch.texture=textures.selected_notch;notch.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;notch.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(notch)
        var state=TextureRect.new();state.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;state.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(state)
        for key in ["normal","hover","pressed","focus","disabled"]:button.add_theme_stylebox_override(key,empty_skin)
        rows[i]={"button":button,"eye":eye,"frame":frame,"notch":notch,"state":state}
func refresh():
    if not scroll:return
    var game=hud.game;var members=[]
    for i in range(game.battle.units.size()):
        var u=game.battle.units[i]
        if u.ally and u.controller=="player":members.append([i,u.id])
    if members!=identities:rebuild(members)
    var area=hud.root.size
    # Hit targets are logical UI pixels; headless screen transforms may be tiny.
    var hit=48.0
    var width=clampf(area.x*.10,hit*1.5,150)
    var top=maxf(90,hud.pause_button.position.y+hud.pause_button.size.y+12)
    var bottom=area.y*.76
    var content_height=rows.size()*maxf(hit,(width-12)*120.0/272.0)+maxi(0,rows.size()-1)*4
    position=Vector2(area.x-width-12,top);size=Vector2(width,minf(maxf(hit,bottom-top),content_height))
    scroll.position=Vector2.ZERO;scroll.size=size
    var blocked=hud.blocks_input() or game.targeting_locked() or game.session.pending
    visible=not rows.is_empty() and not is_instance_valid(hud.modal) and not hud.story_panel.visible and not (game.cutin and game.cutin.active)
    for i in rows:
        var row=rows[i];var u=game.battle.units[i];var done=u.acted and u.moves_used>=u.move_actions
        var frame_width=width-12;var frame_height=frame_width*120.0/272.0
        var row_height=maxf(hit,frame_height);var top_pad=(row_height-frame_height)*.5
        row.button.custom_minimum_size=Vector2(frame_width,row_height);row.button.disabled=blocked or u.hp<=0
        row.button.tooltip_text=u.name+" · "+("已完成" if done else ("已移动，仍可行动" if u.moves_used>0 and not u.acted else "可选择"))
        var selected=i==game.selected
        row.frame.texture=textures.frame_selected if selected or row.button.has_focus() else (textures.frame_moved if u.moves_used>0 or done else textures.frame_normal)
        row.frame.position=Vector2(0,top_pad);row.frame.size=Vector2(frame_width,frame_height)
        var factor=frame_width/272.0
        row.eye.position=Vector2(23*factor,top_pad+25*factor);row.eye.size=Vector2(226,70)*factor
        row.eye.material.set_shader_parameter("faded",1.0 if u.moves_used>0 or done or u.hp<=0 else 0.0)
        row.notch.visible=selected;row.notch.size=Vector2(10,15);row.notch.position=Vector2(-1,(row_height-15)*.5)
        row.state.texture=textures.icon_done if done else (textures.icon_action if not u.acted else textures.icon_move)
        row.state.set_meta("status","done" if done else ("action" if not u.acted else "move"))
        row.state.size=Vector2(16,16);row.state.position=Vector2(frame_width-22,row_height-19)
        if row.eye.texture==null:row.button.text=u.name.left(2)
func activate(index):
    if not rows.has(index) or rows[index].button.disabled:return
    hud.select_hero(index)
func hit_row(point):
    if not get_global_rect().has_point(point):return -1
    for i in rows:
        if rows[i].button.get_global_rect().has_point(point):return i
    return -1
func cancel_pointer():pointer=-2;pressed_index=-1;dragged=false
func down(point,id):
    if pointer!=-2 or not get_global_rect().has_point(point):return false
    pointer=id;pressed_index=hit_row(point);pressed_step=hud.game.battle.step
    if pressed_index>=0 and rows[pressed_index].button.disabled:pressed_index=-1
    start=point;scroll_start=scroll.scroll_vertical;dragged=false
    return true
func drag(point):
    if point.distance_to(start)>=10:dragged=true
    if dragged:scroll.scroll_vertical=scroll_start+int(start.y-point.y)
func up(point,id,canceled=false):
    if pointer!=id:return false
    var chosen=pressed_index;var allowed=not dragged and not canceled and chosen>=0 and hit_row(point)==chosen and hud.game.battle.step==pressed_step
    cancel_pointer()
    if allowed:activate(chosen)
    return true
func _input(event):
    if not is_visible_in_tree():cancel_pointer();return
    if event is InputEventKey or event is InputEventJoypadButton:
        var focused=get_viewport().gui_get_focus_owner();var focused_index=-1
        for i in rows:
            if rows[i].button==focused:focused_index=i;break
        if focused_index>=0:
            var accept=event.is_action("ui_accept") or (event is InputEventKey and event.keycode in [KEY_SPACE,KEY_ENTER]) or (event is InputEventJoypadButton and event.button_index==JOY_BUTTON_A)
            if accept:
                if event.is_pressed() and not event.is_echo():activate(focused_index)
                get_viewport().set_input_as_handled();return
            if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
                var keys=rows.keys();var next=clampi(keys.find(focused_index)+(1 if event.is_action_pressed("ui_down") else -1),0,keys.size()-1)
                rows[keys[next]].button.grab_focus();scroll.ensure_control_visible(rows[keys[next]].button)
                get_viewport().set_input_as_handled();return
    var consumed=false
    if event is InputEventScreenTouch:
        synthetic_until=Time.get_ticks_msec()+500
        if event.pressed:
            if event.index!=0:
                if pointer!=-2:dragged=true
                consumed=pointer!=-2 or get_global_rect().has_point(event.position)
            elif pointer!=-2:dragged=true;consumed=true
            else:consumed=down(event.position,event.index)
        else:
            consumed=up(event.position,event.index,event.canceled)
            # Let native Viewport clear touch focus; world requires its own press.
            if consumed:return
    elif event is InputEventScreenDrag:
        if event.index==pointer:drag(event.position);consumed=true
    elif event is InputEventMouseButton:
        if event.device==-1 or Time.get_ticks_msec()<synthetic_until:
            consumed=get_global_rect().has_point(event.position) or pointer!=-2
        elif event.button_index==MOUSE_BUTTON_LEFT:
            consumed=down(event.position,-1) if event.pressed else up(event.position,-1)
        elif event.pressed and get_global_rect().has_point(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            scroll.scroll_vertical+=int(48)*(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1);consumed=true
    elif event is InputEventMouseMotion and pointer==-1:drag(event.position);consumed=true
    if consumed:get_viewport().set_input_as_handled()
