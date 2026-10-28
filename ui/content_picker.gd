extends Control
# Shared local presentation. Entries are snapshots; the HUD revalidates before targeting.
signal activated(id)
signal canceled
const UI=preload("res://ui/style.gd")
const ART="res://assets/ui/picker_v2/"
var entries=[]
var cells=[]
var title=""
var category="skill"
var panel:Panel
var heading:Label
var back:Button
var scroll:ScrollContainer
var grid:GridContainer
var detail:Label
var empty:Label
var selected_index=-1
var pointer=-2
var pressed_index=-1
var start=Vector2.ZERO
var last=Vector2.ZERO
var dragged=false
var scroll_start=0
var columns=4
var row_height=72.0
var layout_key=Vector3.ZERO
var closing=false
func skin(name,margin):
    var path=ART+"panels/"+name+".png"
    var box=StyleBoxTexture.new();box.texture=load(path)
    for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:box.set_texture_margin(side,margin)
    box.content_margin_left=8;box.content_margin_right=8;box.content_margin_top=6;box.content_margin_bottom=6
    return box
func _ready():
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
    panel=Panel.new();panel.add_theme_stylebox_override("panel",skin("picker_frame",16));add_child(panel)
    heading=UI.label(title,20);heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(heading)
    back=Button.new();back.text="返回";back.mouse_filter=Control.MOUSE_FILTER_IGNORE;back.focus_mode=Control.FOCUS_ALL
    for state in ["normal","hover","pressed","focus"]:back.add_theme_stylebox_override(state,skin("cell_selected" if state=="focus" else "cell_normal",16))
    panel.add_child(back)
    scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(scroll)
    grid=GridContainer.new();grid.columns=4;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.mouse_filter=Control.MOUSE_FILTER_IGNORE;grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);scroll.add_child(grid)
    detail=UI.label("",17);detail.clip_text=true;detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;detail.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(detail)
    empty=UI.label("没有可用条目",20);empty.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(empty)
    for i in range(entries.size()):
        var entry=entries[i];var cell=Button.new();cell.mouse_filter=Control.MOUSE_FILTER_IGNORE;cell.focus_mode=Control.FOCUS_ALL;cell.alignment=HORIZONTAL_ALIGNMENT_LEFT
        # Disabled entries remain focusable so keyboard/touch users can read the reason.
        cell.set_meta("entry_id",entry.id);cell.set_meta("content_icon_key",category+":"+entry.id)
        cell.text=entry.name.left(6)+("…" if entry.name.length()>6 else "")+"\n"+entry.get("compact",entry.summary);cell.clip_text=true;cell.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        var icon_id="bandage" if entry.id=="healing_draught" else entry.id
        var icon_path=ART+"icons/"+icon_id+".png"
        cell.icon=load(icon_path) if ResourceLoader.exists(icon_path) else UI.content_icon(category,entry.id)
        if cell.icon==null:cell.icon=load("res://assets/ui/bottom_dock_reference/icons/"+("icon_skill.png" if category=="skill" else "icon_item.png")) if ResourceLoader.exists("res://assets/ui/bottom_dock_reference/icons/"+("icon_skill.png" if category=="skill" else "icon_item.png")) else load("res://assets/ui/hud_v3/"+("icon_sparkles.png" if category=="skill" else "icon_pouch.png"))
        cell.expand_icon=true;cell.add_theme_constant_override("icon_max_width",36);cell.add_theme_constant_override("h_separation",8)
        for state in ["normal","hover","pressed","focus"]:cell.add_theme_stylebox_override(state,skin("cell_selected" if state=="focus" else "cell_normal",16))
        cell.modulate=Color(.66,.68,.65,1) if not entry.reason.is_empty() else Color.WHITE
        cell.focus_entered.connect(select.bind(i));grid.add_child(cell);cells.append(cell)
    empty.visible=entries.is_empty();heading.text=title+" · "+str(entries.size())
    resized.connect(relayout);relayout()
    if not entries.is_empty():select(0);cells[0].grab_focus()
    else:detail.text="暂无条目 · 返回选择其他行动";back.grab_focus()
func relayout():
    if not panel:return
    var physical=get_window().size;var view=get_viewport_rect().size
    var ratio=1.0 if DisplayServer.get_name()=="headless" else minf(float(physical.x)/view.x,float(physical.y)/view.y)
    var density=maxf(1.0,DisplayServer.screen_get_dpi()/160.0) if OS.has_feature("android") else 1.0
    var hit=maxf(48.0,48.0*density/maxf(ratio,.1));var font=maxi(18,ceili(16/maxf(ratio,.1)))
    var left=size.x*.34 if size.x>=800 else 12.0
    var width=size.x-left-16
    columns=clampi(floori((width-32)/maxf(152,hit*2.1)),1,4);grid.columns=columns
    row_height=maxf(72,hit+12)
    var header=maxf(hit,48);var footer=maxf(40,font+16)
    var dock_top=size.y*.81
    var rows=maxi(1,ceili(float(entries.size())/columns))
    var desired_height=(row_height+8)*minf(2.3,rows)-8
    var grid_height=minf(desired_height,maxf(hit,dock_top-header-footer-40))
    var height=header+grid_height+footer+24
    panel.position=Vector2(left,maxf(8,dock_top-height-8));panel.size=Vector2(width,height)
    heading.position=Vector2(16,12);heading.size=Vector2(width-hit*1.5-40,header-12);heading.add_theme_font_size_override("font_size",font)
    back.position=Vector2(width-hit*1.5-12,8);back.size=Vector2(hit*1.5,hit);back.add_theme_font_size_override("font_size",font)
    scroll.position=Vector2(16,header+12);scroll.size=Vector2(width-32,grid_height)
    detail.position=Vector2(16,header+grid_height+18);detail.size=Vector2(width-32,footer);detail.add_theme_font_size_override("font_size",font)
    empty.position=scroll.position+Vector2(8,12);empty.size=scroll.size-Vector2(16,24)
    var cell_width=(width-52-8*(columns-1))/columns
    for cell in cells:
        cell.custom_minimum_size=Vector2(cell_width,row_height);cell.add_theme_font_size_override("font_size",font)
    if pointer!=-2:cancel_pointer()
func _process(_delta):
    var key=Vector3(size.x,size.y,get_window().size.x)
    if key!=layout_key:layout_key=key;relayout()
func select(index):
    if index<0 or index>=entries.size():return
    selected_index=index
    var entry=entries[index]
    detail.text=entry.name+" · "+(entry.reason+" · " if not entry.reason.is_empty() else "")+entry.summary+" · "+entry.description.replace("\n"," · ")
    detail.tooltip_text=detail.text
func at_point(point):
    if not scroll.get_global_rect().has_point(point):return -1
    for i in range(cells.size()):
        if cells[i].get_global_rect().has_point(point):return i
    return -1
func cancel_pointer():pointer=-2;pressed_index=-1;dragged=false
func down(point,id):
    if pointer!=-2:return
    pointer=id;start=point;last=point;dragged=false;scroll_start=scroll.scroll_vertical
    pressed_index=-3 if back.get_global_rect().has_point(point) else at_point(point)
    if scroll.get_v_scroll_bar().visible and scroll.get_v_scroll_bar().get_global_rect().has_point(point):pressed_index=-4;drag(point)
func drag(point):
    if pointer==-2:return
    if pressed_index==-4:
        var bar=scroll.get_v_scroll_bar();var rect=bar.get_global_rect()
        bar.value=clampf((point.y-rect.position.y)/rect.size.y,0,1)*(bar.max_value-bar.page);dragged=true;return
    if point.distance_to(start)>=10:dragged=true
    if dragged and scroll.get_global_rect().has_point(start):scroll.scroll_vertical=scroll_start+roundi(start.y-point.y)
    last=point
func up(point,id,cancelled=false):
    if pointer!=id:return
    drag(point)
    var chosen=pressed_index;var tap=not dragged and not cancelled
    cancel_pointer()
    if not tap:return
    if chosen==-3 and back.get_global_rect().has_point(point):close();return
    if chosen>=0 and chosen==at_point(point):
        select(chosen);cells[chosen].grab_focus();activate()
func activate():
    if closing or selected_index<0:return
    if not entries[selected_index].reason.is_empty():return
    closing=true;activated.emit(entries[selected_index].id)
func close():
    if closing:return
    closing=true;cancel_pointer();canceled.emit()
func navigate(delta):
    if cells.is_empty():back.grab_focus();return
    var index=clampi(selected_index+delta,0,cells.size()-1);select(index);cells[index].grab_focus();scroll.ensure_control_visible(cells[index])
func _input(event):
    if closing or not is_visible_in_tree():return
    if event is InputEventScreenTouch:
        if event.pressed:down(event.position,event.index)
        else:up(event.position,event.index,event.canceled)
    elif event is InputEventScreenDrag:
        if event.index==pointer:drag(event.position)
    elif event is InputEventMouseButton:
        if event.device!=-1:
            if event.button_index==MOUSE_BUTTON_LEFT:
                if event.pressed:down(event.position,-1)
                else:up(event.position,-1)
            elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and scroll.get_global_rect().has_point(event.position):
                cancel_pointer();scroll.scroll_vertical+=int(row_height)*(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1)
            elif event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:close()
    elif event is InputEventMouseMotion:
        if pointer==-1:drag(event.position)
    elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
        if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_B:close()
        elif event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_A:
            if back.has_focus():close()
            else:activate()
        elif event.is_action_pressed("ui_cancel"):close()
        elif event.is_action_pressed("ui_accept"):
            if back.has_focus():close()
            else:activate()
        elif event.is_action_pressed("ui_right"):navigate(1)
        elif event.is_action_pressed("ui_left"):navigate(-1)
        elif event.is_action_pressed("ui_down"):navigate(columns)
        elif event.is_action_pressed("ui_up"):navigate(-columns)
        elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
            if back.has_focus() and selected_index>=0:cells[selected_index].grab_focus()
            else:back.grab_focus()
    else:return
    get_viewport().set_input_as_handled()
