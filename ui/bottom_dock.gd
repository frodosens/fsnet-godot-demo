extends Control
const ART="res://assets/ui/bottom_dock_reference/"
var hud
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
    picture(canvas,"panels/character-status.png",r("character_panel"))
    portrait=picture(canvas,"character/portrait-mara.png",r("portrait"))
    name_label=label(canvas,"",Rect2(194,823,95,34),30);role_label=label(canvas,"",Rect2(300,829,140,28),23)
    for kind in ["hp","mp"]:
        var rect=r(kind+"_shell");picture(canvas,"bars/"+kind+"-shell.png",rect)
        var bar=TextureProgressBar.new();bar.texture_progress=load(ART+"bars/"+kind+"-fill.png");bar.nine_patch_stretch=true;bar.position=rect.position+Vector2(7,5);bar.size=Vector2(190,10);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(bar)
        if kind=="hp":hp=bar
        else:mp=bar
        label(canvas,kind.to_upper(),Rect2(194,rect.position.y-5,40,28),23)
    hp_value=label(canvas,"",Rect2(450,862,70,28),24);mp_value=label(canvas,"",Rect2(450,890,70,28),24)
    picture(canvas,"icons/icon_move.png",Rect2(194,930,25,25));movement=label(canvas,"",Rect2(225,927,108,30),24)
    picture(canvas,"icons/icon_action_resource.png",Rect2(342,930,25,25));action_value=label(canvas,"",Rect2(375,927,100,30),24)
    picture(canvas,"panels/round-phase.png",r("phase"));phase=label(canvas,"",r("phase"),26);phase.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;phase.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    actions=Control.new();actions.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(actions)
    picture(actions,"panels/action-dock.png",r("action_and_movement_dock"))
    var kinds=["move","attack","skill","item","wait"];var names=["移动","攻击","技能","道具","待机"]
    for i in range(kinds.size()):
        var kind=kinds[i];var a=layout.action_rects[kind];var b=button(actions,kind,names[i],Rect2(a[0],a[1],a[2],a[3]),hud.choose_action.bind(kind));action_nodes[kind]=b
        b.mouse_entered.connect(select.bind(kind));b.focus_entered.connect(select.bind(kind))
    for i in range(kinds.size()):
        var b=action_nodes[kinds[i]];b.focus_neighbor_right=b.get_path_to(action_nodes[kinds[(i+1)%5]]);b.focus_neighbor_left=b.get_path_to(action_nodes[kinds[(i+4)%5]])
    context=Control.new();context.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(context)
    picture(context,"panels/action-dock.png",r("action_and_movement_dock"));picture(context,"icons/icon_move.png",Rect2(580,854,54,54))
    proposal_title=label(context,"移动预览",Rect2(655,850,200,36),30);cost=label(context,"",Rect2(655,900,210,35),24)
    var a=layout.action_rects.confirm;confirm=button(context,"confirm","确认",Rect2(a[0],a[1],182,a[3]),hud.game.confirm_proposal)
    a=layout.action_rects.cancel;cancel=button(context,"cancel","取消",Rect2(1065,a[1],156,a[3]),hud.cancel_targeting)
    confirm.focus_neighbor_right=confirm.get_path_to(cancel);cancel.focus_neighbor_left=cancel.get_path_to(confirm)
    var end=Button.new();end.text="结束回合";end.position=r("end_turn").position;end.size=r("end_turn").size;end.add_theme_font_size_override("font_size",30)
    for state in ["normal","hover","focus","pressed","disabled"]:end.add_theme_stylebox_override(state,skin("panels/end-turn.png"))
    end.pressed.connect(hud.request_end_turn);canvas.add_child(end);hud.turn_button=end;hud.action_buttons.end=end
func select(kind):
    if not action_nodes[kind].disabled:selected=kind
func refresh_dock():
    var view=get_viewport_rect().size;var factor=minf(view.x/1586.0,view.y/992.0);canvas.scale=Vector2.ONE*factor;canvas.position=(view-Vector2(1586,992)*factor)*0.5
    hud.hint_label.hide();hud.log_label.hide();hud.turn_button.text="结束回合" if hud.game.battle.outcome=="playing" else "战斗已结束"
    hud.turn_button.position=r("end_turn").position;hud.turn_button.size=r("end_turn").size
    var physical_ratio=minf(float(get_window().size.x)/view.x,float(get_window().size.y)/view.y)
    for text_node in canvas.find_children("*","Label",true,false):
        text_node.add_theme_font_size_override("font_size",maxi(text_node.get_meta("base_font",24),ceili(16.0/maxf(0.1,factor*physical_ratio))))
    var game=hud.game;var logic=game.battle;var i=game.selected
    phase.text="第 %d 回合 · %s"%[logic.round_number,{"playing":"我方行动","victory":"胜利","defeat":"失败"}.get(logic.outcome,logic.outcome)]
    if i>=0 and i<logic.units.size():
        var u=logic.units[i]
        if portrait_id!=u.id:
            portrait_id=u.id
            var portrait_path=ART+"character/portrait-mara.png" if u.id=="mara" else "res://assets/portraits/"+u.id+".png"
            portrait.texture=load(portrait_path) if ResourceLoader.exists(portrait_path) else null
        name_label.text=u.name;role_label.text={"knight":"骑士","archer":"弓手","mage":"法师"}.get(u.role,u.role)
        hp.max_value=u.max_hp;hp.value=u.hp;mp.max_value=maxi(1,u.max_mp);mp.value=u.mp
        hp_value.text="%d/%d"%[u.hp,u.max_hp];mp_value.text="%d/%d"%[u.mp,u.max_mp]
        movement.text="移动 %d"%maxi(0,u.move_actions-u.moves_used);action_value.text="行动 %d"%(0 if u.acted else 1)
        action_nodes.wait.disabled=not logic.usable(i) or (u.acted and u.moves_used>=u.move_actions)
    var moving=game.mode=="move" and not hud.action_menu_open and not hud.blocks_input() and logic.outcome=="playing"
    actions.visible=hud.action_menu_open and not hud.blocks_input() and logic.outcome=="playing"
    context.visible=moving or (game.mode!="move" and not hud.action_menu_open and not hud.blocks_input() and logic.outcome=="playing")
    proposal_title.text="移动预览" if game.mode=="move" else "目标预览"
    confirm.disabled=(game.pending_move.is_empty() and game.pending_target.is_empty()) or game.targeting_locked()
    cost.text="请选择落点" if game.preview_path.is_empty() else "%d 格 · 移动 1 次"%[game.preview_path.size()-1]
    if game.mode!="move":cost.text="再点目标确认" if not game.pending_target.is_empty() else "请选择目标"
    if not game.queued_confirmation.is_empty():cost.text="等待同步确认"
    for kind in action_nodes:
        var b=action_nodes[kind];b.text="";b.add_theme_stylebox_override("normal",skin("buttons/"+("selected" if selected==kind and not b.disabled else "normal")+".png"))
        b.get_meta("caption").modulate=Color("a4aaa4") if b.disabled else Color("eee2c6")
