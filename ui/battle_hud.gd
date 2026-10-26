extends CanvasLayer
const UI=preload("res://ui/style.gd")
var game
var root
var round_label
var net_label
var detail
var log_label
var hero_column
var action_buttons={}
var story_panel
var story_name
var story_text
var story_count
var portrait
var portrait_initial
var story_key=""
var modal
var gear_open=false
var last_step=-1
var action_panel
var action_menu_open=true
var status_panel
var companion_panel
var pause_button
var turn_button
var hint_label
var target_panel
var target_portrait
var target_detail
var hp_bar
var mp_bar
var hp_label
var mp_label
var move_label
var act_label
var hp_icon
var mp_icon
var action_summary
var selected_portrait
var previous=[]
var log_lines=[]
func _ready():
    root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.theme=UI.make_theme();add_child(root)
    var route=preload("res://view/path_preview.gd").new();route.game=game;root.add_child(route)
    soft_panel(Vector2(20,18),Vector2(310,104))
    var heading=UI.label(game.battle.content.title,28);heading.position=Vector2(28,24);root.add_child(heading)
    var objective=UI.paragraph(objective_text(game.battle.content.victory),280);objective.position=Vector2(28,66);objective.add_theme_font_size_override("font_size",18);root.add_child(objective)
    round_label=UI.label("",22);round_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;round_label.position=Vector2(530,20);round_label.size=Vector2(220,42);root.add_child(round_label)
    net_label=UI.label("",14);net_label.position=Vector2(28,97);root.add_child(net_label)
    pause_button=UI.menu_button("暂停 Esc",toggle_pause);pause_button.add_theme_font_size_override("font_size",18);pause_button.custom_minimum_size=Vector2(132,40);root.add_child(pause_button)
    companion_panel=ScrollContainer.new();companion_panel.position=Vector2(24,540);companion_panel.custom_minimum_size=Vector2(380,66);root.add_child(companion_panel)
    hero_column=HBoxContainer.new();hero_column.add_theme_constant_override("separation",10);companion_panel.add_child(hero_column)
    var hidden_heading=UI.label("");hidden_heading.hide();hero_column.add_child(hidden_heading)
    for i in range(game.battle.units.size()):
        var unit=game.battle.units[i]
        if unit.ally or unit.controller=="player":
            var button=Button.new();button.custom_minimum_size=Vector2(48,60);button.tooltip_text=unit.name;button.pressed.connect(select_hero.bind(i));hero_column.add_child(button)
            var image=UI.portrait(unit.id,48);image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);image.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(image)
            if image.texture==null:button.text=unit.name.left(1)
            var health=preload("res://ui/art_meter.gd").new();health.position=Vector2(4,56);health.size=Vector2(40,3);health.max_value=unit.max_hp;health.value=unit.hp;health.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(health)
            art_frame(button,"ally_portrait_frame")
    status_panel=Control.new();status_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;status_panel.size=Vector2(500,160);root.add_child(status_panel)
    selected_portrait=UI.portrait("mara",88);selected_portrait.position=Vector2(0,-26);selected_portrait.size=Vector2(112,152);status_panel.add_child(selected_portrait);art_frame(selected_portrait,"portrait_frame")
    detail=UI.paragraph("",270);detail.position=Vector2(124,2);detail.add_theme_font_size_override("font_size",22);status_panel.add_child(detail)
    action_summary=HBoxContainer.new();action_summary.add_theme_constant_override("separation",8);status_panel.add_child(action_summary)
    action_summary.add_child(art_icon("symbol_movement"));move_label=UI.label("",20);action_summary.add_child(move_label)
    action_summary.add_child(art_icon("symbol_action"));act_label=UI.label("",20);action_summary.add_child(act_label)
    hp_icon=art_icon("icon_hp");status_panel.add_child(hp_icon);mp_icon=art_icon("icon_mp");status_panel.add_child(mp_icon)
    hp_bar=stat_bar(status_panel,Vector2(124,62),Color("8ba078"),"hp");mp_bar=stat_bar(status_panel,Vector2(124,91),Color("6c9c9b"),"mp")
    hp_label=UI.label("",22);hp_label.position=Vector2(292,54);status_panel.add_child(hp_label)
    mp_label=UI.label("",22);mp_label.position=Vector2(292,83);status_panel.add_child(mp_label)
    hint_label=UI.label("选择角色，Enter 打开行动",22);hint_label.position=Vector2(440,744);root.add_child(hint_label)
    log_label=UI.label("",16);log_label.position=Vector2(440,710);root.add_child(log_label)
    turn_button=UI.button("空格 · 结束回合",request_end_turn);turn_button.add_theme_font_size_override("font_size",18);turn_button.custom_minimum_size=Vector2(210,44);root.add_child(turn_button);action_buttons["end"]=turn_button
    action_panel=Control.new();action_panel.size=Vector2(158,216);action_panel.z_index=10;root.add_child(action_panel)
    for i in range(4):
        var kind=["move","attack","skill","item"][i];var button=preload("res://ui/action_button.gd").new();button.kind=kind;button.text=["1   移动","2   攻击","3   技能","4   道具"][i];button.position=Vector2(0,i*54);button.pressed.connect(choose_action.bind(kind));action_panel.add_child(button);action_buttons[kind]=button
    target_panel=soft_panel(Vector2(960,90),Vector2(280,110));target_panel.hide()
    target_portrait=UI.portrait("oren",56);target_portrait.position=Vector2(0,8);target_panel.add_child(target_portrait)
    target_detail=UI.paragraph("",220);target_detail.position=Vector2(62,0);target_detail.add_theme_font_size_override("font_size",16);target_panel.add_child(target_detail)
    story_panel=panel(Vector2(20,558),Vector2(1240,224));story_panel.z_index=30
    var story_row=HBoxContainer.new();story_row.add_theme_constant_override("separation",20);story_panel.add_child(story_row)
    var image_box=PanelContainer.new();image_box.custom_minimum_size=Vector2(164,184);story_row.add_child(image_box)
    portrait=TextureRect.new();portrait.custom_minimum_size=Vector2(140,160);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image_box.add_child(portrait)
    portrait_initial=UI.label("信",48);portrait_initial.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;portrait_initial.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;image_box.add_child(portrait_initial)
    var words=UI.column(story_row,10);words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    story_name=UI.label("",23);words.add_child(story_name)
    story_text=UI.paragraph("",740);story_text.custom_minimum_size.y=100;words.add_child(story_text)
    story_count=UI.label("",14);words.add_child(story_count)
    var choices=UI.column(story_row,12);choices.custom_minimum_size.x=150
    choices.add_child(UI.button("下一句 · 空格",advance.bind(false)))
    choices.add_child(UI.button("跳过本段",advance.bind(true)))
    choices.add_child(UI.button("暂停 / 保存",toggle_pause))
    var flag=preload("res://ui/round_flag.gd").new();round_label.add_child(flag);flag.show_behind_parent=true
    root.resized.connect(refresh)
    refresh()
func objective_text(goal):
    match goal.kind:
        "defeat_all":return "目标 · 击退所有敌人"
        "all_allies":return "目标 · 所有友方失去战力"
        "reach":return "目标 · %s到达 (%d,%d)"%[goal.unit,goal.x,goal.y]
        "survive":return "目标 · 坚持到第 %d 回合"%goal.round
        "protect":return "条件 · %s失去战力"%goal.unit
        "all","any":
            var parts=[]
            for child in goal.children:parts.append(objective_text(child).trim_prefix("目标 · "))
            return ("全部：" if goal.kind=="all" else "任一：")+"；".join(parts)
    return "目标条件"
func soft_panel(pos,size):
    var control=Control.new();control.position=pos;control.size=size;root.add_child(control)
    var bg=TextureRect.new();var texture=GradientTexture2D.new();texture.width=128;texture.height=32
    var gradient=Gradient.new();gradient.set_color(0,Color(0.12,0.17,0.16,0.9));gradient.set_color(1,Color(0.12,0.17,0.16,0));texture.gradient=gradient;texture.fill_from=Vector2.ZERO;texture.fill_to=Vector2.RIGHT
    bg.texture=texture;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;control.add_child(bg);return control
func art_frame(parent,name):
    var frame=TextureRect.new();frame.texture=load("res://assets/ui/hud_v3/"+name+".png");frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;frame.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;frame.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
    frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);parent.add_child(frame)
func art_icon(name):
    var icon=preload("res://ui/responsive_art_icon.gd").new();icon.asset_name=name;icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(20,20);icon.size=Vector2(20,20);icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;return icon
func stat_bar(parent,pos,_color,kind):
    var bar=preload("res://ui/art_meter.gd").new();bar.kind=kind;bar.position=pos;bar.size=Vector2(160,12);parent.add_child(bar);return bar
func panel(pos,size):
    var p=PanelContainer.new();p.position=pos;p.custom_minimum_size=size;root.add_child(p);return p
func select_hero(index):
    if blocks_input():return
    game.selected=index;action_menu_open=true;game.refresh()
func request_end_turn():
    if blocks_input():return
    var remaining=false
    for unit in game.battle.units:
        if unit.controller=="player" and unit.hp>0 and (not unit.acted or unit.moves_used<unit.move_actions):remaining=true
    if not remaining:game.finish_turn();return
    var page=modal_page("结束本回合？")
    page.add_child(UI.paragraph("仍有队员可以移动或行动。结束后将交由 AI 行动。",550))
    page.add_child(UI.button("确认结束",confirm_end_turn));page.add_child(UI.button("继续行动",clear_modal))
func confirm_end_turn():clear_modal();game.finish_turn()
func cancel_targeting():
    game.mode="move";game.clear_move_preview();game.target_preview={};game.target_preview_index=-1;action_menu_open=true;refresh()
func open_action_menu():
    if blocks_input() or game.selected<0:return
    action_menu_open=true;game.clear_move_preview();refresh();action_buttons.move.grab_focus()
func choose_action(kind):
    action_menu_open=false
    if kind=="skill":show_abilities()
    elif kind=="item":show_items()
    else:game.select_mode(kind)
    refresh()
func blocks_input():return game.presentation_active() or is_instance_valid(modal) or (story_panel and story_panel.visible)
func refresh():
    if not root:return
    var logic=game.battle
    round_label.text="第 %d 回合 · %s"%[logic.round_number,{"playing":"我方行动","victory":"胜利","defeat":"失败"}.get(logic.outcome,logic.outcome)]
    var view=root.get_viewport_rect().size
    round_label.position.x=(view.x-220)*0.5;pause_button.position=Vector2(view.x-maxf(132,pause_button.size.x)-24,24)
    status_panel.position=Vector2(view.x*0.02,view.y*0.84);status_panel.size=Vector2(view.x*0.40,view.y*0.16)
    selected_portrait.position=Vector2(0,-view.y*0.04);selected_portrait.size=Vector2(view.x*0.085,view.y*0.16)
    detail.position=Vector2(view.x*0.10,0);action_summary.position=Vector2(view.x*0.10,view.y*0.105)
    hp_bar.position=Vector2(view.x*0.12,view.y*0.045);mp_bar.position=Vector2(view.x*0.12,view.y*0.075)
    hp_bar.size=Vector2(view.x*0.12,view.x*0.009);mp_bar.size=hp_bar.size
    hp_icon.position=hp_bar.position+Vector2(-28,-4);mp_icon.position=mp_bar.position+Vector2(-28,-4)
    hp_label.position=Vector2(view.x*0.245,view.y*0.035);mp_label.position=Vector2(view.x*0.245,view.y*0.065)
    companion_panel.position=Vector2(view.x*0.135-24,view.y*0.80-30);companion_panel.custom_minimum_size=Vector2(380,64);companion_panel.size.y=64
    hero_column.add_theme_constant_override("separation",maxi(0,int(view.x*0.04)-48))
    turn_button.position=Vector2(view.x-maxf(210,turn_button.size.x)-24,view.y-90);hint_label.position=Vector2(430,view.y-56);log_label.position=Vector2(430,view.y-90)
    story_panel.position=Vector2((view.x-1240)*0.5,view.y-242)
    for line in [hint_label,log_label]:
        line.clip_text=true;line.custom_minimum_size.x=0;line.size.x=maxf(100,view.x-690);line.tooltip_text=line.text
    net_label.text="离线旅程" if not game.session.online else ("已连接 · 合作小队" if game.session.status.begins_with("Online") else "连接中 / 正在重连")
    if game.session.failed:net_label.text="连接失败 · 请返回重试"
    var button_index=1
    for i in range(logic.units.size()):
        var u=logic.units[i]
        if u.ally or u.controller=="player":
            var b=hero_column.get_child(button_index);button_index+=1
            b.tooltip_text="%s %d/%d · %s"%[u.name,u.hp,u.max_hp,"友军 AI" if u.controller=="ai" else "选择队员"]
            b.disabled=u.hp<=0 or u.controller!="player"
            b.visible=game.selected!=i
            b.get_child(1).max_value=u.max_hp;b.get_child(1).value=u.hp
            var border=StyleBoxFlat.new();border.bg_color=Color(0.12,0.17,0.16,0.7);border.border_color=Color("dfa75f") if game.selected==i else Color("59624b");border.set_border_width_all(2 if game.selected==i else 1);b.add_theme_stylebox_override("normal",border)
    detail.text="队伍休整中。";move_label.text="";act_label.text=""
    var active=game.selected>=0 and logic.usable(game.selected)
    if active:
        var u=logic.units[game.selected]
        var image="res://assets/portraits/"+u.id+".png"
        selected_portrait.texture=load(image) if ResourceLoader.exists(image) else null
        var skill="默认技能："+u.skill_id
        for ability in logic.content.abilities:
            if ability.id==u.skill_id:skill="默认技能："+ability.name;detail.tooltip_text=ability_description(ability)
        detail.text="%s · %s"%[u.name,{"knight":"骑士","archer":"弓手","mage":"法师","raider":"卫队长","scout":"斥候","brute":"桥工"}.get(u.role,u.role)]
        detail.tooltip_text=skill+"\n"+detail.tooltip_text
        move_label.text="移动 %d"%maxi(0,u.move_actions-u.moves_used);act_label.text="行动 %d"%(0 if u.acted else 1)
        hp_bar.max_value=u.max_hp;hp_bar.value=u.hp;mp_bar.max_value=maxi(1,u.max_mp);mp_bar.value=u.mp
        hp_label.text="%d/%d"%[u.hp,u.max_hp];mp_label.text="%d/%d"%[u.mp,u.max_mp]
        action_buttons.move.text="1   移动"
        action_buttons.move.disabled=u.moves_used>=u.move_actions
        action_buttons.attack.disabled=u.acted
        action_buttons.skill.disabled=u.acted
        action_buttons.item.disabled=u.acted
        action_buttons.move.tooltip_text="本回合移动次数已用尽" if action_buttons.move.disabled else "指向地块预览合法路线，点击确认移动"
        for kind in ["attack","skill","item"]:action_buttons[kind].tooltip_text="本回合行动已用尽" if u.acted else "选择目标后由共同规则校验"
    else:
        for kind in ["move","attack","skill","item"]:action_buttons[kind].disabled=true
    action_buttons.end.disabled=logic.outcome!="playing"
    action_panel.visible=active and not blocks_input()
    target_panel.visible=not game.target_preview.is_empty() and game.mode!="move" and not blocks_input()
    if target_panel.visible:
        var victim=logic.units[game.target_preview_index];var prediction=game.target_preview
        target_panel.position=Vector2(view.x-304,90)
        var image="res://assets/portraits/"+victim.id+".png";target_portrait.texture=load(image) if ResourceLoader.exists(image) else null
        target_detail.text="%s · HP %d/%d\n伤害 %d–%d"%[victim.name,victim.hp,victim.max_hp,prediction.low,prediction.high]
        if prediction.crit_chance>0:target_detail.text+="\n每段暴击 %d%% · %d–%d"%[prediction.crit_chance,prediction.critical_low,prediction.critical_high]
        if prediction.healing>0:target_detail.text+="\n治疗 +%d"%prediction.healing
    if active:
        # Approved reference uses a right-hand safe zone, away from selected units.
        action_panel.position=Vector2(view.x*0.88-32,view.y*0.31-32)
        action_panel.size=Vector2(view.x*0.12+16,view.y*0.28+64)
        var kinds=["move","attack","skill","item"];var anchors=[0.31,0.41,0.50,0.59]
        for i in range(4):
            var button=action_buttons[kinds[i]];button.position=Vector2(0,(anchors[i]-0.31)*view.y)
            button.custom_minimum_size.x=view.x*0.12+16;button.size.x=button.custom_minimum_size.x
            button.set_selected(game.mode==kinds[i] or (kinds[i]=="skill" and game.mode.begins_with("ability:")) or (kinds[i]=="item" and game.mode.begins_with("item:")))
        hint_label.text=("移动 %d/%d · 点击落点确认"%[game.preview_path.size()-1,logic.units[game.selected].movement]) if not game.preview_path.is_empty() else ("指向地块预览路线 · Enter 行动" if game.mode=="move" else "选择合法目标 · Esc 返回")
        if game.mode=="move" and not game.preview_reason.is_empty():hint_label.text=game.preview_reason
    if last_step!=logic.step:
        if last_step>=0 and logic.step>last_step:
            var changes=[]
            for i in range(mini(previous.size(),logic.units.size())):
                var u=logic.units[i];var old=previous[i]
                if u.hp<old.hp:changes.append("%s 受到 %d 点伤害"%[u.name,old.hp-u.hp])
                elif u.hp>old.hp:changes.append("%s 恢复 %d 点生命"%[u.name,u.hp-old.hp])
                if u.pos!=old.pos and u.ally:changes.append(u.name+"移动到新位置")
            if changes.is_empty():changes.append("进入第 %d 回合"%logic.round_number)
            for text in changes:log_lines.append(text)
            while log_lines.size()>5:log_lines.pop_front()
        last_step=logic.step;previous=logic.units.duplicate(true)
        if gear_open:call_deferred("show_gear")
    log_label.text=log_lines[-1] if not log_lines.is_empty() else ""
    refresh_story()
func refresh_story():
    var line=App.next_story()
    story_panel.visible=not line.is_empty() and not is_instance_valid(modal) and not game.presentation_active()
    if line.is_empty():story_key="";return
    var key=line.id+":"+str(line.index)
    if key==story_key:return
    story_key=key;story_name.text=App.speaker_name(line.speaker);story_text.text=line.text;story_count.text="%d / %d · 剧情仅控制本地阅读，联机对局不会因此暂停。"%[line.index,line.total] if game.session.online else "%d / %d"%[line.index,line.total]
    portrait.texture=null
    var path="res://assets/portraits/"+line.speaker+".png"
    if ResourceLoader.exists(path):
        portrait.texture=load(path)
    portrait_initial.visible=portrait.texture==null
    portrait_initial.text="信" if line.speaker=="narrator" else App.speaker_name(line.speaker).left(1)
func advance(skip):
    App.advance_story(skip);refresh_story()
func clear_modal():
    gear_open=false
    if is_instance_valid(modal):root.remove_child(modal);modal.queue_free();modal=null
    refresh_story()
func modal_page(title):
    clear_modal()
    modal=ColorRect.new();modal.color=Color(0.08,0.07,0.05,0.7);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.z_index=100;root.add_child(modal)
    var p=PanelContainer.new();p.position=Vector2((root.get_viewport_rect().size.x-600)*0.5,100);p.custom_minimum_size=Vector2(600,0);modal.add_child(p)
    var c=UI.column(p,12);c.add_child(UI.label(title,28));story_panel.visible=false;return c
func toggle_pause():
    if is_instance_valid(modal):clear_modal();return
    var c=modal_page("旅程菜单")
    c.add_child(UI.paragraph("本地暂停操作不会暂停网络房间。" if game.session.online else "休息片刻，旅程会等你。",550))
    c.add_child(UI.button("继续战斗",clear_modal))
    var save=UI.button("保存旅程",show_save);save.disabled=game.session.online;save.tooltip_text="网络房间由主机维护，本版不允许客户端写本地战斗存档。";c.add_child(save)
    var gear=UI.button("装备整备 / 背包",show_gear);c.add_child(gear)
    if not game.session.online:c.add_child(UI.button("重新开始本场",confirm_restart))
    c.add_child(UI.button("返回主界面",confirm_leave.bind(false)))
    c.add_child(UI.button("退出游戏",confirm_leave.bind(true)))
    c.get_child(2).grab_focus()
func show_save():
    var c=modal_page("选择存档位置")
    for slot in App.SLOT_IDS:
        var info=App.inspect_slot(slot)
        var text={"auto":"自动存档","slot1":"存档一","slot2":"存档二","slot3":"存档三"}[slot]
        text+=" · "+(info.error if not info.error.is_empty() else "第 %d 回合"%info.round)
        c.add_child(UI.button(text,confirm_save.bind(slot)))
    c.add_child(UI.button("返回",func():clear_modal();toggle_pause()))
func confirm_save(slot):
    if FileAccess.file_exists(App.save_path(slot)):
        var c=modal_page("替换现有存档？")
        c.add_child(UI.paragraph("只有新文件完整写入后才会替换原文件。",550))
        c.add_child(UI.button("确认保存",perform_save.bind(slot)))
        c.add_child(UI.button("取消",show_save))
    else:perform_save(slot)
func perform_save(slot):
    var error=App.save_slot(slot)
    if error.is_empty():clear_modal();log_lines.append("旅程已保存。");refresh()
    else:
        var c=modal_page("保存未完成");c.add_child(UI.paragraph(error,550));c.add_child(UI.button("返回战斗",clear_modal))
func confirm_restart():
    var c=modal_page("重新开始？");c.add_child(UI.paragraph("本场未保存的行动和剧情阅读进度会重置。已有存档保留。",550))
    c.add_child(UI.button("重新开始",func():clear_modal();game.restart()))
    c.add_child(UI.button("继续当前旅程",clear_modal))
func confirm_leave(quit_game):
    if not App.dirty() and not game.session.online:leave(quit_game);return
    var c=modal_page("退出游戏？" if quit_game else "返回主界面？")
    if game.session.online:
        c.add_child(UI.paragraph("你是主机，离开会关闭房间，其他玩家将断开。网络进度本版不会保存。" if App.server else "离开将断开网络对局。当前房间由主机继续维护。",550))
    else:
        c.add_child(UI.paragraph("当前旅程有未保存进度。可以保存到自动存档后离开。",550))
        c.add_child(UI.button("保存并离开",save_and_leave.bind(quit_game)))
    c.add_child(UI.button("直接离开" if game.session.online else "不保存，离开",leave.bind(quit_game)))
    c.add_child(UI.button("继续旅程",clear_modal))
func save_and_leave(quit_game):
    var error=App.save_slot("auto")
    if error.is_empty():leave(quit_game)
    else:
        var c=modal_page("无法保存");c.add_child(UI.paragraph(error,550));c.add_child(UI.button("继续旅程",clear_modal))
func leave(quit_game):
    if quit_game:App.close_room();get_tree().quit()
    else:App.return_to_menu()

func ability_description(ability):
    var parts=["目标："+{"self":"自身","ally":"同阵营","enemy":"其他阵营"}[ability.target],"额外射程 +%d · 法力 %d · 冷却 %d 回合"%[ability.reach_bonus,ability.mp_cost,ability.cooldown]]
    for effect in ability.effects:
        parts.append(("治疗 %d"%effect.value if effect.op=="heal" else "攻击 +%d（%s）"%[effect.value,"法术" if ability.damage_type=="magic" else "物理"])+(" · 半径 %d"%effect.radius if effect.radius>0 else ""))
    parts.append("暴击 %d%% · 倍率 %d%%"%[ability.get("crit_chance",0),ability.get("crit_multiplier",150)])
    if ability.stationary:parts.append("移动后需行咒装备方可施放")
    return "\n".join(parts)
func scroll_list(parent):
    var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(550,280);parent.add_child(scroll)
    var list=UI.column(scroll,8);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;return list
func show_abilities():
    if blocks_input() or game.selected<0:return
    var u=game.battle.units[game.selected]
    var page=modal_page(u.name+" · 技能");var list=scroll_list(page)
    for i in range(game.battle.content.abilities.size()):
        var ability=game.battle.content.abilities[i]
        if ability.id=="attack" or ability.id not in u.abilities:continue
        var note="法力 %d · 冷却 %d 回合"%[ability.mp_cost,u.cooldowns[i]]
        if ability.charges>0:note+=" · 余 %d 次"%u.charges[i]
        if ability.stationary:note+=" · 移动后不可施放" if not u.get("mobile_cast",false) else " · 行走施法已生效"
        var button=UI.button(ability.name+"　"+note,choose_ability.bind(ability.id))
        button.disabled=u.acted or u.mp<ability.mp_cost or u.cooldowns[i]>0 or (ability.charges>0 and u.charges[i]==0) or (ability.stationary and u.moves_used>0 and not u.get("mobile_cast",false))
        button.tooltip_text=ability_description(ability);list.add_child(button)
    page.add_child(UI.button("返回",clear_modal))
func choose_ability(id):
    clear_modal();game.select_mode("ability:"+id)

var gear_unit=0
var gear_slot=0
func item_text(item):
    var data=game.battle.content.equipment
    var base=data.bases[item.base-1]
    var text=["普通","魔法","稀有","独特"][item.quality]+" · "+(base.unique_name if item.quality==3 else base.name)+" #"+str(item.uid)
    var bonuses=[]
    for key in base.stats:bonuses.append(str(key)+" +"+str(base.stats[key]))
    for entry in item.affixes:
        var affix=data.affixes[entry.index-1]
        bonuses.append(affix.name+(" +"+str(entry.value) if affix.stat!="none" else ""))
    if not bonuses.is_empty():text+="\n"+" / ".join(bonuses)
    return text
func show_gear():
    var logic=game.battle
    var page=modal_page("小队整备 · 背包")
    gear_open=true;modal.get_child(0).position.y=24
    var selectors=HBoxContainer.new();page.add_child(selectors)
    var people=OptionButton.new();selectors.add_child(people)
    for i in range(logic.units.size()):
        if logic.units[i].controller=="player":people.add_item(logic.units[i].name,i)
    people.select(people.get_item_index(gear_unit))
    people.item_selected.connect(func(index):gear_unit=people.get_item_id(index);show_gear())
    var slots=OptionButton.new();selectors.add_child(slots)
    for name in ["主手","副手","头部","身体","双手","双脚","项链","戒指一","戒指二"]:slots.add_item(name)
    slots.select(gear_slot);slots.item_selected.connect(func(index):gear_slot=index;show_gear())
    if people.item_count==0:
        page.add_child(UI.paragraph("此关卡没有玩家控制的单位，无法整备。",550));page.add_child(UI.button("返回",clear_modal));return
    if people.get_item_index(gear_unit)<0:gear_unit=people.get_item_id(0);people.select(0)
    var u=logic.units[gear_unit]
    page.add_child(UI.paragraph("生命上限 %d · 攻击 %d · 法术加成 %d · 护甲 %d · 抗性 %d\n每回合移动 %d 次；%s"%[u.max_hp,u.damage,u.spell_bonus,u.armor,u.resist,u.move_actions,"行走施法" if u.mobile_cast else "凝神光矢需原地施放"],550))
    var allowed=(logic.preparation or logic.outcome!="playing") and not game.session.pending
    page.add_child(UI.paragraph("整备开放。装备变化不会恢复生命或行动次数。" if allowed else "战斗开始后装备锁定，胜负结算后重新开放。",550))
    var current=u.equipment[gear_slot]
    var equipped_text="此槽位为空"
    for item in logic.inventory:
        if item.uid==current:equipped_text="当前："+item_text(item)
    page.add_child(UI.paragraph(equipped_text,550))
    var remove=UI.button("卸下当前装备",equip_item.bind(0));remove.disabled=not allowed or current==0;page.add_child(remove)
    var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(550,160);page.add_child(scroll)
    var list=UI.column(scroll,8);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var slot_id=["main_hand","off_hand","head","body","hands","feet","neck","ring","ring"][gear_slot]
    for item in logic.inventory:
        if logic.content.equipment.bases[item.base-1].slot!=slot_id:continue
        var owned=false
        for unit in logic.units:
            if item.uid in unit.equipment:owned=true
        var button=UI.button(item_text(item)+(" · 已穿戴" if owned else " · 装备"),equip_item.bind(item.uid));button.disabled=not allowed or owned;list.add_child(button)
    page.add_child(UI.button("返回旅程菜单",func():clear_modal();toggle_pause()))
func equip_item(uid):
    game.session.submit({"kind":"equip","unit":gear_unit,"slot":gear_slot,"item":uid})
    game.battle=game.session.logic;game.refresh();show_gear()

func show_items():
    if blocks_input() or game.selected<0:return
    var page=modal_page("共用行囊 · 消耗品")
    page.add_child(UI.paragraph("使用道具消耗本回合行动；目标与消耗遵循对应技能说明。",550))
    var list=scroll_list(page);var u=game.battle.units[game.selected]
    for i in range(game.battle.content.consumables.size()):
        var item=game.battle.content.consumables[i]
        var button=UI.button(item.name+" ×"+str(game.battle.supplies[i]),choose_item.bind(item.id));button.disabled=game.battle.supplies[i]<=0 or u.acted
        for j in range(game.battle.content.abilities.size()):
            var ability=game.battle.content.abilities[j]
            if ability.id==item.ability:
                button.tooltip_text=ability_description(ability)
                button.disabled=button.disabled or u.mp<ability.mp_cost or u.cooldowns[j]>0 or (ability.charges>0 and u.charges[j]==0) or (ability.stationary and u.moves_used>0 and not u.mobile_cast)
        list.add_child(button)
    page.add_child(UI.button("返回",clear_modal))
func choose_item(id):clear_modal();game.select_mode("item:"+id)
