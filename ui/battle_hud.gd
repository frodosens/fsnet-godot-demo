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
var previous=[]
var log_lines=[]
func _ready():
    root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.theme=UI.make_theme();add_child(root)
    var top=panel(Vector2(20,16),Vector2(1240,64))
    var row=HBoxContainer.new();row.add_theme_constant_override("separation",20);top.add_child(row)
    row.add_child(UI.label("琥珀桥来信",24))
    round_label=UI.label("");round_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(round_label)
    net_label=UI.label("",14);row.add_child(net_label)
    row.add_child(UI.button("旅程菜单 · Esc",toggle_pause))
    var party=panel(Vector2(20,98),Vector2(210,0));hero_column=UI.column(party,10)
    hero_column.add_child(UI.label("护送小队",22))
    for i in range(game.battle.units.size()):
        if game.battle.units[i].ally:hero_column.add_child(UI.button(game.battle.units[i].name,select_hero.bind(i)))
    var bottom=panel(Vector2(254,610),Vector2(1006,172))
    var layout=HBoxContainer.new();layout.add_theme_constant_override("separation",22);bottom.add_child(layout)
    detail=UI.paragraph("",270);layout.add_child(detail)
    var actions=UI.column(layout,8)
    var line=HBoxContainer.new();actions.add_child(line)
    for entry in [["移动","move"],["普通攻击","attack"],["职业技能","skill"]]:
        var b=UI.button("技能列表" if entry[1]=="skill" else entry[0],show_abilities if entry[1]=="skill" else game.select_mode.bind(entry[1]));line.add_child(b);action_buttons[entry[1]]=b
    var item_button=UI.button("道具",show_items);line.add_child(item_button);action_buttons["item"]=item_button
    var finish=UI.button("结束本回合 · 空格",game.finish_turn);actions.add_child(finish);action_buttons["end"]=finish
    var hint=UI.label("点选队员 → 选择行动 → 点击目标。",14);actions.add_child(hint)
    var journal=UI.column(layout,4);journal.add_child(UI.label("战斗记录",17));log_label=UI.paragraph("委托开始。",270);log_label.add_theme_font_size_override("font_size",14);journal.add_child(log_label)
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
    refresh()
func panel(pos,size):
    var p=PanelContainer.new();p.position=pos;p.custom_minimum_size=size;root.add_child(p);return p
func select_hero(index):
    if blocks_input():return
    game.selected=index;game.refresh()
func blocks_input():return is_instance_valid(modal) or (story_panel and story_panel.visible)
func refresh():
    if not root:return
    var logic=game.battle
    round_label.text="第 %d 回合  ·  %s"%[logic.round_number,{"playing":"护送进行中","victory":"桥已通行","defeat":"暂退河岸"}.get(logic.outcome,logic.outcome)]
    net_label.text="离线旅程" if not game.session.online else ("已连接 · 合作小队" if game.session.status.begins_with("Online") else "连接中 / 正在重连")
    if game.session.failed:net_label.text="连接失败 · 请返回重试"
    var button_index=1
    for i in range(logic.units.size()):
        var u=logic.units[i]
        if u.ally:
            var b=hero_column.get_child(button_index);button_index+=1
            b.text="%s  %d/%d\n%s"%[u.name,u.hp,u.max_hp,"失去战力" if u.hp<=0 else ("当前选中" if game.selected==i else "点击选择")]
            b.disabled=u.hp<=0
    detail.text="队伍休整中。"
    var active=game.selected>=0 and logic.usable(game.selected)
    if active:
        var u=logic.units[game.selected]
        var skill={"knight":"重整：自身恢复 3 生命","archer":"强射：射程 +1，伤害 +1","mage":"余烬：射程 +1，小范围伤害"}.get(u.role,"无职业技能")
        detail.text="%s · %s\n生命 %d/%d  法力 %d/%d\n移动 %d 格 · 攻击距离 %d\n%s"%[u.name,{"knight":"骑士","archer":"弓手","mage":"法师"}.get(u.role,u.role),u.hp,u.max_hp,u.mp,u.max_mp,u.movement,u.reach,skill]
        action_buttons.move.text="移动 · 余 %d"%maxi(0,u.move_actions-u.moves_used)
        action_buttons.move.disabled=u.moves_used>=u.move_actions
        action_buttons.attack.disabled=u.acted
        action_buttons.skill.disabled=u.acted
        action_buttons.item.disabled=u.acted
    else:
        for kind in ["move","attack","skill","item"]:action_buttons[kind].disabled=true
    action_buttons.end.disabled=logic.outcome!="playing"
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
    log_label.text="\n".join(log_lines) if not log_lines.is_empty() else "药箱与家书等待过桥。"
    refresh_story()
func refresh_story():
    var line=App.next_story()
    story_panel.visible=not line.is_empty() and not is_instance_valid(modal)
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
    var p=PanelContainer.new();p.position=Vector2(340,145);p.custom_minimum_size=Vector2(600,0);modal.add_child(p)
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

func show_abilities():
    if blocks_input() or game.selected<0:return
    var u=game.battle.units[game.selected]
    var page=modal_page(u.name+" · 技能")
    for i in range(game.battle.content.abilities.size()):
        var ability=game.battle.content.abilities[i]
        if ability.id=="attack" or ability.id not in u.abilities:continue
        var note="法力 %d · 冷却 %d 回合"%[ability.mp_cost,u.cooldowns[i]]
        if ability.charges>0:note+=" · 余 %d 次"%u.charges[i]
        if ability.stationary:note+=" · 移动后不可施放" if not u.get("mobile_cast",false) else " · 行走施法已生效"
        var button=UI.button(ability.name+"　"+note,choose_ability.bind(ability.id))
        button.disabled=u.acted or u.mp<ability.mp_cost or u.cooldowns[i]>0 or (ability.charges>0 and u.charges[i]==0) or (ability.stationary and u.moves_used>0 and not u.get("mobile_cast",false))
        page.add_child(button)
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
    page.add_child(UI.paragraph("使用道具消耗当前单位的本回合行动。选择后点击合法友方目标。",550))
    for i in range(game.battle.content.consumables.size()):
        var item=game.battle.content.consumables[i]
        var button=UI.button(item.name+" ×"+str(game.battle.supplies[i]),choose_item.bind(item.id));button.disabled=game.battle.supplies[i]<=0;page.add_child(button)
    page.add_child(UI.button("返回",clear_modal))
func choose_item(id):clear_modal();game.select_mode("item:"+id)
