extends Control
# Presentation-only browser. All mutations are authoritative equip commands.
signal canceled
const UI=preload("res://ui/style.gd")
const Model=preload("res://ui/character_details_model.gd")
var hud
var actor=-1
var actor_id=""
var session
var generation=0
var model=Model.new()
var panel:Panel
var portrait:TextureRect
var identity:Label
var summary:Label
var xp_group:Control
var xp_bar:TextureProgressBar
var tabs=[]
var back:Button
var list:ScrollContainer
var column:VBoxContainer
var description:ScrollContainer
var body:Label
var equipment_scroll:ScrollContainer
var equipment_text:Label
var detail_layer:Panel
var detail_scroll:ScrollContainer
var detail_text:Label
var detail_back:Button
var full:Button
var equip:Button
var rows=[]
var tab=0
var slot=0
var selected_uid=-1
var selected_key=""
var scroll_positions={}
var description_open=false
var closing=false
var pointer=-2
var pressed:Control
var outside=false
var start=Vector2.ZERO
var dragged=false
var drag_scroll:ScrollContainer
var scroll_start=0
var fingerprint=""
var last_pending=false
var elapsed=0.0
var skins={}
const ART="res://assets/ui/character_details_v2/"
const CONTRACT=preload("res://ui/character_details_geometry.gd")
var portrait_frame:NinePatchRect
var title_label:Label
var class_label:Label
var level_label:Label
var footer_label:Label
var close_button:Button
var identity_panel:Panel
var attributes_panel:Panel
var traits_panel:Panel
var equipment_panel:Panel
var attributes_heading:Label
var traits_heading:Label
var equipment_heading:Label
var body_scroll:ScrollContainer
var body_canvas:Control
var stat_rows=[]
var layout_scale=1.0
var compact=false
var xp_frame:NinePatchRect
var manifest={}
func art_skin(name,_margin=0):
    if not skins.has(name):
        var box=StyleBoxTexture.new();box.texture=load(ART+name+".png")
        var spec=manifest[name]
        var caps=spec.get("cap_margins_ltrb_px",[0,0,0,0])
        var pads=spec.get("content_padding_ltrb_px",[0,0,0,0])
        for i in range(4):
            var side=[SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM][i]
            box.set_texture_margin(side,caps[i]);box.set_content_margin(side,pads[i])
        skins[name]=box
    return skins[name]
func skin(selected=false):return art_skin("tab_selected" if selected else "tab_normal")
func ui_ratio():return maxf(.25,minf(float(get_window().size.x)/get_viewport_rect().size.x,float(get_window().size.y)/get_viewport_rect().size.y))
func hit_size():return 48/ui_ratio() if compact else maxf(44/ui_ratio(),64*layout_scale)
func make_label(parent,text,font=26):
    var node=UI.label(text,font);node.set_meta("details_font",font);node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(node);return node
func make_button(parent,text,callback,asset="return_button"):
    var node=Button.new();node.text=text;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.clip_text=true;node.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    node.set_meta("details_button_asset",asset)
    for state in ["normal","hover","pressed","disabled"]:node.add_theme_stylebox_override(state,art_skin(asset))
    var focus=StyleBoxEmpty.new();node.add_theme_stylebox_override("focus",focus);node.add_theme_color_override("font_focus_color",Color("eed49a"))
    node.pressed.connect(callback);parent.add_child(node);return node
func make_scroll(parent):
    var node=ScrollContainer.new();node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;parent.add_child(node);return node
func make_panel(parent,asset="inset_panel"):
    var node=Panel.new();node.mouse_filter=Control.MOUSE_FILTER_IGNORE;node.add_theme_stylebox_override("panel",art_skin(asset));parent.add_child(node);return node
func make_art(parent,asset):
    var node=TextureRect.new();node.texture=load(ART+asset+".png");node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(node);return node
func _ready():
    manifest=JSON.parse_string(FileAccess.get_file_as_string(ART+"manifest.json")).assets
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
    session=hud.game.session;generation=session.connection_generation;actor_id=hud.game.battle.units[actor].id
    panel=make_panel(self,"modal_panel")
    title_label=make_label(panel,"角色资料",44);title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    close_button=make_button(panel,"",close,"close_button")
    identity_panel=make_panel(panel)
    portrait=UI.portrait(actor_id);portrait.custom_minimum_size=Vector2.ZERO;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;portrait.clip_contents=true;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;identity_panel.add_child(portrait)
    portrait_frame=NinePatchRect.new();portrait_frame.texture=load(ART+"portrait_frame.png");portrait_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
    for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:portrait_frame.set_patch_margin(side,26)
    identity_panel.add_child(portrait_frame)
    identity=make_label(identity_panel,"",38);class_label=make_label(identity_panel,"",23);level_label=make_label(identity_panel,"",26)
    for label in [identity,class_label,level_label]:
        label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    summary=make_label(identity_panel,"",18);summary.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;summary.autowrap_mode=TextServer.AUTOWRAP_OFF;summary.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    xp_group=Control.new();xp_group.mouse_filter=Control.MOUSE_FILTER_IGNORE;identity_panel.add_child(xp_group)
    xp_frame=NinePatchRect.new();xp_frame.texture=load(ART+"xp_frame.png");xp_frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
    xp_frame.patch_margin_left=12;xp_frame.patch_margin_right=12;xp_frame.patch_margin_top=6;xp_frame.patch_margin_bottom=6;xp_group.add_child(xp_frame)
    xp_bar=TextureProgressBar.new();xp_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;xp_bar.texture_progress=load(ART+"xp_fill.png");xp_bar.nine_patch_stretch=true;xp_group.add_child(xp_bar)
    for i in range(4):
        var button=make_button(panel,["属性","技能","队伍道具","装备"][i],change_tab.bind(i),"tab_normal")
        button.icon=load(ART+["icon_helmet","icon_sparkle","icon_pouch","icon_armor"][i]+".png");button.expand_icon=true;tabs.append(button)
    back=make_button(panel,"返回",close)
    footer_label=make_label(panel,"共享背包 · 查看不消耗行动",21);footer_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    body_scroll=make_scroll(panel);body_canvas=Control.new();body_canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;body_canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body_scroll.add_child(body_canvas)
    attributes_panel=make_panel(body_canvas);attributes_heading=make_label(attributes_panel,"基础属性",30)
    for i in range(10):
        var row=Control.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;attributes_panel.add_child(row)
        var icon=make_art(row,["icon_heart","icon_shield","icon_book","icon_resistance","icon_sword","icon_crosshair","icon_sparkle","icon_boot","icon_boot","icon_hourglass"][i])
        var label=make_label(row,"");label.autowrap_mode=TextServer.AUTOWRAP_OFF;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        var value=make_label(row,"");value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;value.autowrap_mode=TextServer.AUTOWRAP_OFF;value.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        var divider=make_art(row,"divider");stat_rows.append({"root":row,"icon":icon,"label":label,"value":value,"divider":divider})
    list=make_scroll(attributes_panel);column=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_child(column)
    traits_panel=make_panel(body_canvas);traits_heading=make_label(traits_panel,"装备特性",30)
    description=make_scroll(traits_panel);body=make_label(description,"");body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    equipment_panel=make_panel(panel);equipment_heading=make_label(equipment_panel,"当前装备",30)
    equipment_scroll=make_scroll(equipment_panel);equipment_text=make_label(equipment_scroll,"",23);equipment_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    full=make_button(panel,"完整说明",open_description);equip=make_button(panel,"装备",commit_equipment)
    detail_layer=make_panel(self);detail_layer.hide()
    detail_back=make_button(detail_layer,"返回资料",close_description);detail_scroll=make_scroll(detail_layer);detail_text=make_label(detail_scroll,"");detail_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    resized.connect(relayout);relayout();refresh_data(true);tabs[0].grab_focus()
func relayout():
    CONTRACT.arrange(self)
func update_stats(unit):
    var data=model.attribute_rows(unit)
    for i in range(stat_rows.size()):
        stat_rows[i].label.text=data[i].name;stat_rows[i].value.text=data[i].value
func current():
    var game=hud.game
    return game.session==session and session.connection_generation==generation and actor>=0 and actor<game.battle.units.size() and game.battle.units[actor].id==actor_id and game.selected==actor and not game.presentation_active()
func _process(delta):
    if closing:return
    if not current():close();return
    elapsed+=delta
    if elapsed>=.2:elapsed=0;refresh_data()
func change_tab(index):
    scroll_positions[tab]=list.scroll_vertical;tab=index;selected_key="";selected_uid=-1;description_open=false;detail_layer.hide();refresh_data(true);relayout()
    # Outer content belongs to navigation, not the previous tab's scrolled summary.
    # Preserve each inner list offset, but always reveal that list after switching.
    body_scroll.scroll_vertical=0
    body_scroll.set_deferred("scroll_vertical",0)
    list.set_deferred("scroll_vertical",scroll_positions.get(tab,0))
func add_row(text,key,callback,icon=null):
    var button=make_button(column,text,callback,"list_row");button.custom_minimum_size.y=hit_size();button.add_theme_font_size_override("font_size",roundi(16/ui_ratio()) if compact else roundi(24*layout_scale));button.set_meta("key",key);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    if icon:button.icon=icon;button.expand_icon=true;button.add_theme_constant_override("icon_max_width",32)
    rows.append(button)
func refresh_data(force=false):
    if not current():close();return
    var logic=hud.game.battle;var key=logic.state_hash()
    if not force and key==fingerprint:
        if last_pending!=session.pending:
            last_pending=session.pending
            if tab==3 and selected_uid>=0:choose_equipment(selected_uid)
        return
    last_pending=session.pending
    fingerprint=key;cancel_pointer()
    for i in range(tabs.size()):tabs[i].add_theme_stylebox_override("normal",skin(i==tab))
    var old_scroll=list.scroll_vertical
    for child in column.get_children():column.remove_child(child);child.queue_free()
    rows.clear()
    var u=logic.units[actor]
    identity.text=u.name
    class_label.text={"knight":"骑士","archer":"弓手","mage":"法师"}.get(u.role,u.role)
    var growth=model.progression(u);xp_group.visible=growth.available
    if growth.available:
        level_label.text="Lv."+str(growth.level)
        xp_bar.max_value=maxi(1,growth.required);xp_bar.value=xp_bar.max_value if growth.capped else growth.current
        summary.text="已满级" if growth.capped else "经验 %d / %d"%[growth.current,growth.required]
        summary.tooltip_text="累计经验 %d"%growth.total
    else:
        level_label.text="Lv. —";summary.text="经验数据暂不可用"
    update_stats(u)
    var gear_lines=[]
    for i in range(9):
        var text="空"
        for item in logic.inventory:
            if item.uid==u.equipment[i]:text=hud.item_text(item)
        gear_lines.append(Model.SLOT_NAMES[i]+"："+text)
    equipment_text.text="\n".join(gear_lines)
    equip.visible=tab==3;equip.disabled=true
    if tab==0:
        body.text="移动施法："+("允许" if u.get("mobile_cast",false) else "不允许")
        for item in logic.inventory:
            if item.uid in u.equipment:body.text+="\n"+hud.item_text(item)
        if u.equipment.all(func(uid):return uid==0):body.text+="\n尚未穿戴装备"
    elif tab in [1,2]:
        var entries=hud.picker_entries("skill" if tab==1 else "item")
        var selection_found=false
        for entry in entries:
            var text=entry.name+" · "+entry.summary
            var details=entry.name+"\n"+entry.summary+"\n"+entry.reason+"\n\n"+entry.description
            add_row(text,entry.id,select_text.bind(entry.id,details),UI.content_icon("skill" if tab==1 else "item",entry.id))
            if selected_key==entry.id:body.text=details;selection_found=true
        if entries.is_empty():body.text="暂无技能" if tab==1 else "共享背包暂无道具"
        elif not selection_found:select_text(entries[0].id,entries[0].name+"\n"+entries[0].summary+"\n"+entries[0].reason+"\n\n"+entries[0].description)
    else:
        for i in range(9):add_row("▸ "+Model.SLOT_NAMES[i]+(" · 当前槽位" if i==slot else ""),"slot"+str(i),choose_slot.bind(i))
        add_row("卸下当前装备","item0",choose_equipment.bind(0))
        for item in model.inventory(logic,actor,slot):
            add_row(item.name+(" · "+item.owner+"已穿戴" if not item.owner.is_empty() else ""),"item"+str(item.uid),choose_equipment.bind(item.uid),UI.content_icon("equipment",item.base_id))
        if selected_uid>=0:choose_equipment(selected_uid)
        else:body.text="请选择"+Model.SLOT_NAMES[slot]+"装备查看实际属性变化。\n"+model.equipment_reason(logic,actor,session.pending)
    list.set_deferred("scroll_vertical",old_scroll)
    if description_open:detail_text.text=body.text
    relayout()
func select_text(key,text):
    selected_key=key;body.text=text;description.scroll_vertical=0
func choose_slot(index):slot=index;selected_uid=-1;refresh_data(true)
func choose_equipment(uid):
    selected_uid=uid;selected_key="item"+str(uid)
    var logic=hud.game.battle;var reason=model.equipment_reason(logic,actor,session.pending)
    if logic.units[actor].equipment[slot]==uid:reason="已经穿戴此装备" if uid!=0 else "槽位已为空"
    var preview=model.preview_equipment(logic,actor,slot,uid) if reason.is_empty() else {"allowed":false,"reason":reason,"changes":[]}
    var text="卸下" if uid==0 else "装备"
    for item in logic.inventory:
        if item.uid==uid:text=hud.item_text(item)
    var lines=[text,preview.reason]
    for change in preview.changes:lines.append(change.name+"："+str(change.before)+" → "+str(change.after))
    if preview.allowed and preview.changes.is_empty():lines.append("显示属性不变")
    body.text="\n".join(lines);equip.text="卸下" if uid==0 else "装备";equip.disabled=not preview.allowed
func commit_equipment():
    if not current() or selected_uid<0:return
    var logic=hud.game.battle
    if not model.equipment_reason(logic,actor,session.pending).is_empty():refresh_data(true);return
    if logic.units[actor].equipment[slot]==selected_uid:return
    if not model.preview_equipment(logic,actor,slot,selected_uid).allowed:refresh_data(true);return
    equip.disabled=true;cancel_pointer()
    session.submit({"kind":"equip","unit":actor,"actor_id":actor_id,"slot":slot,"item":selected_uid})
    hud.game.battle=session.logic;hud.game.refresh();refresh_data(true)
func open_description():
    cancel_pointer();description_open=true;detail_text.text=body.text;detail_scroll.scroll_vertical=0;detail_layer.show();detail_back.grab_focus()
func close_description():cancel_pointer();description_open=false;detail_layer.hide();full.grab_focus()
func close():
    if closing:return
    if description_open:close_description();return
    closing=true;cancel_pointer();canceled.emit()
func cancel_pointer():pointer=-2;pressed=null;drag_scroll=null;dragged=false
func active_panel():return detail_layer if description_open else panel
func controls():return [detail_back] if description_open else tabs+[close_button,back,full,equip]+([] if tab==0 else rows)
func point_visible(node,point):
    var ancestor=node.get_parent()
    while ancestor!=self and ancestor!=null:
        if ancestor is ScrollContainer and not ancestor.get_global_rect().has_point(point):return false
        ancestor=ancestor.get_parent()
    return true
func hit(point):
    for node in controls():
        if not node.is_visible_in_tree() or node.disabled:continue
        if not point_visible(node,point):continue
        if node.get_global_rect().has_point(point):return node
    return null
func down(point,id):
    if pointer!=-2:dragged=true;pressed=null;return
    pointer=id;start=point;dragged=false;pressed=hit(point);outside=not active_panel().get_global_rect().has_point(point)
    for scroll in ([detail_scroll] if description_open else [list,description,equipment_scroll,body_scroll]):
        if scroll.is_visible_in_tree() and scroll.get_v_scroll_bar().max_value>scroll.get_v_scroll_bar().page and scroll.get_global_rect().has_point(point) and point_visible(scroll,point):drag_scroll=scroll;scroll_start=scroll.scroll_vertical;break
func drag(point):
    if pointer==-2:return
    if point.distance_to(start)>=10:dragged=true
    if dragged and drag_scroll:drag_scroll.scroll_vertical=scroll_start+roundi(start.y-point.y)
func up(point,id,cancelled=false):
    if pointer!=id:return
    drag(point);var button=pressed;var tap=not dragged and not cancelled;var dismiss=outside and not active_panel().get_global_rect().has_point(point);cancel_pointer()
    if not tap:return
    if dismiss:close();return
    if is_instance_valid(button) and hit(point)==button:button.grab_focus();button.pressed.emit()
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
            elif event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:close()
            elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
                for scroll in ([detail_scroll] if description_open else [list,description,equipment_scroll,body_scroll]):
                    if scroll.is_visible_in_tree() and scroll.get_v_scroll_bar().max_value>scroll.get_v_scroll_bar().page and scroll.get_global_rect().has_point(event.position) and point_visible(scroll,event.position):scroll.scroll_vertical+=64*(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1);break
    elif event is InputEventMouseMotion:
        if pointer==-1:drag(event.position)
    elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
        if event.is_action_pressed("ui_cancel"):close()
        elif event.is_action_pressed("ui_accept"):
            var focused=get_viewport().gui_get_focus_owner()
            if focused in controls() and not focused.disabled:focused.pressed.emit()
        elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
            var scroll=detail_scroll if description_open else (body_scroll if tab==0 and body_scroll.get_v_scroll_bar().max_value>body_scroll.size.y else (description if tab==0 else list))
            scroll.scroll_vertical+=64*(1 if event.is_action_pressed("ui_down") else -1)
        elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
            var available=controls().filter(func(n):return n.is_visible_in_tree() and not n.disabled);var at=available.find(get_viewport().gui_get_focus_owner());available[posmod(at+(1 if event.is_action_pressed("ui_focus_next") else -1),available.size())].grab_focus()
    else:return
    if event is InputEventScreenTouch and not event.pressed:return
    get_viewport().set_input_as_handled()
