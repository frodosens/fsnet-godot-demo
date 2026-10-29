extends Control
const ContentPicker=preload("res://ui/content_picker.gd")
const ART="res://assets/ui/bottom_dock_reference/"
var hud
var status_group:Control
var canvas:Control
var actions:Control
var context:Control
var portrait:TextureRect
var name_label:Label
var role_label:Label
var hp_value:Label
var mp_value:Label
var movement:Label
var action_value:Label
var phase_group:Control
var phase:Label
var cost:Label
var proposal_title:Label
var hp:TextureProgressBar
var mp:TextureProgressBar
var confirm:Button
var cancel:Button
var action_nodes={}
var selected="move"
var layout=JSON.parse_string(FileAccess.get_file_as_string(ART+"layout.json"))
var portrait_id=""
var details_button:Button
var portrait_button:Button
var details_pointer=-2
var details_pressed:Button
var details_start=Vector2.ZERO
var details_dragged=false
var notice:Label
var targeting_legend:Label
var skins={}
func picture(parent,path,rect):
    var t=TextureRect.new();t.texture=load(ART+path);t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;t.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;t.mouse_filter=Control.MOUSE_FILTER_IGNORE;t.position=rect.position;t.size=rect.size;parent.add_child(t);return t
func label(parent,text,rect,font=28):
    var n=Label.new();n.text=text;n.position=rect.position;n.size=rect.size;n.add_theme_font_size_override("font_size",font);n.add_theme_color_override("font_color",Color("eee2c6"));n.mouse_filter=Control.MOUSE_FILTER_IGNORE;n.set_meta("base_font",font);parent.add_child(n);return n
func r(key):
    var a=layout.rects[key];return Rect2(a[0],a[1],a[2],a[3])
func skin(path):
    if skins.has(path):return skins[path]
    var s=StyleBoxTexture.new();s.texture=load(ART+path);s.texture_margin_left=12;s.texture_margin_right=12;s.texture_margin_top=12;s.texture_margin_bottom=12;skins[path]=s;return s
func button(parent,kind,title,rect,callback):
    var b=Button.new();b.position=rect.position;b.size=rect.size;b.custom_minimum_size=Vector2.ZERO;b.tooltip_text=title;b.mouse_filter=Control.MOUSE_FILTER_STOP;b.pressed.connect(callback)
    for state in ["normal","hover","focus","pressed","disabled"]:b.add_theme_stylebox_override(state,skin("buttons/"+("disabled" if state=="disabled" else ("selected" if state in ["hover","focus","pressed"] else "normal"))+".png"))
    parent.add_child(b)
    var horizontal=kind in ["confirm","cancel"]
    picture(b,"icons/icon_"+kind+".png",Rect2(14 if horizontal else 34,28 if horizontal else 12,32 if horizontal else 56,32 if horizontal else 56))
    var title_node=label(b,title,Rect2(54 if horizontal else 0,24 if horizontal else 81,rect.size.x-68 if horizontal else rect.size.x,40),28)
    if horizontal:
        title_node.clip_text=true;title_node.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    else:title_node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    b.set_meta("caption",title_node);return b
func setup(owner):
    hud=owner;mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    canvas=Control.new();canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.size=Vector2(1586,992);add_child(canvas)
    status_group=Control.new();status_group.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(status_group)
    picture(status_group,"panels/character-status.png",r("character_panel"))
    portrait=picture(status_group,"character/portrait-mara.png",r("portrait"))
    portrait_button=Button.new();portrait_button.flat=true;portrait_button.mouse_filter=Control.MOUSE_FILTER_IGNORE;portrait_button.position=r("portrait").position;portrait_button.size=r("portrait").size;portrait_button.tooltip_text="角色资料";portrait_button.pressed.connect(hud.show_character_details);status_group.add_child(portrait_button)
    details_button=Button.new();details_button.text="资料";details_button.mouse_filter=Control.MOUSE_FILTER_IGNORE;details_button.icon=load("res://assets/ui/character_details_v1/profile_button.png");details_button.expand_icon=true;details_button.add_theme_constant_override("icon_max_width",26);details_button.pressed.connect(hud.show_character_details);details_button.position=Vector2(430,796);details_button.size=Vector2(88,64);status_group.add_child(details_button)
    name_label=label(status_group,"",Rect2(194,823,95,34),30);role_label=label(status_group,"",Rect2(300,829,140,28),23)
    for kind in ["hp","mp"]:
        var rect=r(kind+"_shell");picture(status_group,"bars/"+kind+"-shell.png",rect)
        var bar=TextureProgressBar.new();bar.texture_progress=load(ART+"bars/"+kind+"-fill.png");bar.nine_patch_stretch=true;bar.position=rect.position+Vector2(7,5);bar.size=Vector2(190,10);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;status_group.add_child(bar)
        if kind=="hp":hp=bar
        else:mp=bar
        label(status_group,kind.to_upper(),Rect2(194,rect.position.y-5,40,28),23)
    hp_value=label(status_group,"",Rect2(450,862,70,28),24);mp_value=label(status_group,"",Rect2(450,890,70,28),24)
    picture(status_group,"icons/icon_move.png",Rect2(194,930,25,25));movement=label(status_group,"",Rect2(225,927,108,30),24)
    picture(status_group,"icons/icon_action_resource.png",Rect2(342,930,25,25));action_value=label(status_group,"",Rect2(375,927,100,30),24)
    phase_group=Control.new();phase_group.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(phase_group)
    picture(phase_group,"panels/round-phase.png",r("phase"));phase=label(phase_group,"",r("phase"),26);phase.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;phase.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    notice=label(canvas,"",Rect2(545,779,1020,36),24)
    targeting_legend=label(canvas,"色块：距离 · 白角：可选 · 金色：效果 · 红叉：不可选",Rect2(545,779,1020,36),24)
    targeting_legend.hide()
    actions=Control.new();actions.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(actions)
    picture(actions,"panels/action-dock.png",r("action_and_movement_dock"))
    var kinds=["move","attack","skill","item","wait"];var names=["移动","攻击","技能","道具","待机"]
    for i in range(kinds.size()):
        var kind=kinds[i];var a=layout.action_rects[kind];var b=button(actions,kind,names[i],Rect2(a[0],a[1],a[2],a[3]),hud.choose_action.bind(kind));action_nodes[kind]=b
        b.mouse_entered.connect(select.bind(kind));b.focus_entered.connect(select.bind(kind))
    for i in range(kinds.size()):
        var b=action_nodes[kinds[i]];b.focus_neighbor_right=b.get_path_to(action_nodes[kinds[(i+1)%5]]);b.focus_neighbor_left=b.get_path_to(action_nodes[kinds[(i+4)%5]])
    context=Control.new();context.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(context)
    var strip=Panel.new();strip.position=Vector2(545,710);strip.size=Vector2(1020,96);strip.mouse_filter=Control.MOUSE_FILTER_IGNORE
    strip.add_theme_stylebox_override("panel",skin("buttons/normal.png"));context.add_child(strip)
    proposal_title=label(context,"移动预览",Rect2(560,736,200,36),26);cost=label(context,"",Rect2(775,736,300,35),24)
    cost.clip_text=true;cost.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    confirm=button(context,"confirm","确认",Rect2(1100,716,190,84),hud.game.confirm_proposal)
    cancel=button(context,"cancel","取消",Rect2(1300,716,170,84),hud.cancel_targeting)
    confirm.focus_neighbor_right=confirm.get_path_to(cancel);cancel.focus_neighbor_left=cancel.get_path_to(confirm)
    var end=Button.new();end.text="结束回合";end.position=r("end_turn").position;end.size=r("end_turn").size;end.add_theme_font_size_override("font_size",30)
    for state in ["normal","hover","focus","pressed","disabled"]:end.add_theme_stylebox_override(state,skin("panels/end-turn.png"))
    end.pressed.connect(hud.request_end_turn);canvas.add_child(end);hud.turn_button=end;hud.action_buttons.end=end
func select(kind):
    if not action_nodes[kind].disabled:selected=kind
func refresh_dock():
    var view=get_viewport_rect().size
    var factor=maxf(.01,minf(hud.root.size.x/1586.0,hud.root.size.y/992.0))
    canvas.scale=Vector2.ONE*factor
    # Bottom controls and top phase have independent safe-area edge anchors.
    canvas.position=Vector2((hud.root.size.x-1586*factor)*.5,hud.root.size.y-992*factor)
    phase_group.position.y=-canvas.position.y/factor
    hud.hint_label.hide();hud.log_label.hide();hud.turn_button.text="结束回合" if hud.game.battle.outcome=="playing" else "战斗已结束"
    status_group.position.x=maxf(0.0,-canvas.position.x/factor)
    hud.turn_button.position=r("end_turn").position;hud.turn_button.size=r("end_turn").size
    hud.turn_button.position.x=minf(hud.turn_button.position.x,(hud.root.size.x-canvas.position.x)/factor-hud.turn_button.size.x-12)
    var physical_ratio=minf(float(get_window().size.x)/view.x,float(get_window().size.y)/view.y)
    for text_node in canvas.find_children("*","Label",true,false):
        text_node.add_theme_font_size_override("font_size",maxi(text_node.get_meta("base_font",24),ceili(16.0/maxf(0.1,factor*physical_ratio))))
    details_button.size=Vector2(maxf(88,48/factor),maxf(64,48/factor));details_button.position.x=529-details_button.size.x
    var game=hud.game;var logic=game.battle;var i=game.selected
    details_button.disabled=i<0 or hud.blocks_input() or game.session.command_pending or game.presentation_active()
    portrait_button.disabled=details_button.disabled
    phase.text="第 %d 回合 · %s"%[logic.round_number,{"playing":"我方行动","victory":"胜利","defeat":"失败"}.get(logic.outcome,logic.outcome)]
    if i>=0 and i<logic.units.size():
        var u=logic.units[i]
        if portrait_id!=u.id:
            portrait_id=u.id
            var portrait_path=ART+"character/portrait-mara.png" if u.id=="mara" else preload("res://view/reserve_art.gd").portrait_path(u.id)
            portrait.texture=load(portrait_path) if ResourceLoader.exists(portrait_path) else null
        name_label.text=u.name;role_label.text={"knight":"骑士","archer":"弓手","mage":"法师"}.get(u.role,u.role)
        hp.max_value=u.max_hp;hp.value=u.hp;mp.max_value=maxi(1,u.max_mp);mp.value=u.mp
        hp_value.text="%d/%d"%[u.hp,u.max_hp];mp_value.text="%d/%d"%[u.mp,u.max_mp]
        movement.text="移动 %d"%maxi(0,u.move_actions-u.moves_used);action_value.text="行动 %d"%(0 if u.acted else 1)
        var spent=u.acted and u.moves_used>=u.move_actions
        action_nodes.wait.disabled=not logic.usable(i) or game.targeting_locked()
        action_nodes.wait.get_meta("caption").text="待机"
        notice.text=(u.name+"行动已结束 · 点待机切换队员；全员完成则结束回合") if spent else (hud.action_notice if not hud.action_notice.is_empty() else "点击角色选择 · 拖动地图查看 · 待机仅结束当前角色行动")
    else:
        action_nodes.wait.disabled=true;notice.text="请选择可以行动的队员"
    var moving=game.mode=="move" and not hud.action_menu_open and not hud.blocks_input() and logic.outcome=="playing"
    var picker_open=hud.modal is ContentPicker
    actions.visible=(not hud.blocks_input() or picker_open) and logic.outcome=="playing"
    context.visible=moving or (game.mode!="move" and not hud.action_menu_open and not hud.blocks_input() and logic.outcome=="playing")
    proposal_title.text="移动预览" if game.mode=="move" else "目标预览"
    confirm.disabled=(game.pending_move.is_empty() and game.pending_target.is_empty()) or game.targeting_locked()
    notice.position.y=666 if context.visible else 779;targeting_legend.position.y=674;targeting_legend.hide()
    cost.tooltip_text=""
    cost.text="请选择落点" if game.preview_path.is_empty() else "%d 格 · 移动 1 次"%[game.preview_path.size()-1]
    if game.mode!="move":
        cost.text="再点目标施放" if not game.pending_target.is_empty() else "先点目标预览"
        var preview=game.ground_overlay.targeting_state() if game.ground_overlay else {}
        if preview.get("active",false):
            notice.position.y=634;targeting_legend.show()
            notice.text=preview.summary
            if not preview.reason.is_empty():cost.text="再点目标施放" if preview.hover_legal else preview.reason
            else:cost.text="描边可选 · 再点施放"
            cost.tooltip_text=preview.summary+"\n橙红攻击／紫色技能／青绿辅助：距离参考；白角：合法目标；金色：效果区域；红叉：不可选"
        cost.clip_text=true;cost.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
    elif moving:
        cost.text="再点落点移动" if not game.pending_move.is_empty() else cost.text
    confirm.tooltip_text="可再次点击同一目标直接确认，也可使用此按钮或 Enter"
    if not game.queued_confirmation.is_empty():cost.text="等待同步确认"
    for kind in action_nodes:
        var b=action_nodes[kind]
        if picker_open:b.disabled=true
        b.text="";b.add_theme_stylebox_override("normal",skin("buttons/"+("selected" if selected==kind and not b.disabled else "normal")+".png"))
        b.get_meta("caption").modulate=Color("a4aaa4") if b.disabled else Color("eee2c6")

func picker_bottom_limit():
    return canvas.position.y+779*canvas.scale.y

func details_hit(point):
    for button in [details_button,portrait_button]:
        if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):return button
    return null
func _input(event):
    var point=Vector2.ZERO;var down=false;var up=false;var id=-2;var cancelled=false
    if event is InputEventScreenTouch:point=event.position;down=event.pressed;up=not event.pressed;id=event.index;cancelled=event.canceled
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.device!=-1:point=event.position;down=event.pressed;up=not event.pressed;id=-1
    elif event is InputEventScreenDrag:
        if event.index!=details_pointer:return
        if event.position.distance_to(details_start)>10:details_dragged=true
        get_viewport().set_input_as_handled();return
    elif event is InputEventMouseMotion and details_pointer==-1:
        if event.position.distance_to(details_start)>10:details_dragged=true
        get_viewport().set_input_as_handled();return
    else:return
    if down:
        if details_pointer!=-2:details_dragged=true;return
        var button=details_hit(point)
        if button==null:return
        details_pointer=id;details_pressed=button;details_start=point;details_dragged=false
        get_viewport().set_input_as_handled()
    elif up and id==details_pointer:
        var button=details_pressed;var activate=not cancelled and not details_dragged and point.distance_to(details_start)<=10 and details_hit(point)==button
        details_pointer=-2;details_pressed=null
        if activate:button.grab_focus();hud.show_character_details()
        if not event is InputEventScreenTouch:get_viewport().set_input_as_handled()
