extends RefCounted
# Gear screen and the character-details entry point. It owns no nodes; the HUD
# keeps modal/root/gear_unit so tests can drive the same state as the UI.

const UI=preload("res://ui/style.gd")

var hud


func _init(owner) -> void:
    hud = owner

func show_gear():
    var logic=hud.game.battle
    var page=hud.modal_page("小队整备 · 背包")
    hud.gear_open=true;hud.modal.get_child(0).position.y=24
    var selectors=HBoxContainer.new();page.add_child(selectors)
    var people=OptionButton.new();selectors.add_child(people)
    for i in range(logic.units.size()):
        if logic.units[i].controller=="player":people.add_item(logic.units[i].name,i)
    people.select(people.get_item_index(hud.gear_unit))
    people.item_selected.connect(func(index):hud.gear_unit=people.get_item_id(index);show_gear())
    var slots=OptionButton.new();selectors.add_child(slots)
    for name in ["主手","副手","头部","身体","双手","双脚","项链","戒指一","戒指二"]:slots.add_item(name)
    slots.select(hud.gear_slot);slots.item_selected.connect(func(index):hud.gear_slot=index;show_gear())
    if people.item_count==0:
        page.add_child(UI.paragraph("此关卡没有玩家控制的单位，无法整备。",550));page.add_child(UI.button("返回",hud.clear_modal));return
    if people.get_item_index(hud.gear_unit)<0:hud.gear_unit=people.get_item_id(0);people.select(0)
    var u=logic.units[hud.gear_unit]
    page.add_child(UI.paragraph("生命上限 %d · 攻击 %d · 法术加成 %d · 护甲 %d · 抗性 %d\n每回合移动 %d 次；%s"%[u.max_hp,u.damage,u.spell_bonus,u.armor,u.resist,u.move_actions,"行走施法" if u.mobile_cast else "凝神光矢需原地施放"],550))
    var allowed=(logic.preparation or logic.outcome!="playing") and not hud.game.session.pending
    page.add_child(UI.paragraph("整备开放。装备变化不会恢复生命或行动次数。" if allowed else "战斗开始后装备锁定，胜负结算后重新开放。",550))
    var current=u.equipment[hud.gear_slot]
    var equipped_text="此槽位为空"
    for item in logic.inventory:
        if item.uid==current:equipped_text="当前："+hud.item_text(item)
    page.add_child(UI.paragraph(equipped_text,550))
    var remove=UI.button("卸下当前装备",equip_item.bind(0));remove.disabled=not allowed or current==0;page.add_child(remove)
    var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(550,160);page.add_child(scroll)
    var list=UI.column(scroll,8);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var slot_id=["main_hand","off_hand","head","body","hands","feet","neck","ring","ring"][hud.gear_slot]
    for item in logic.inventory:
        if logic.content.equipment.bases[item.base-1].slot!=slot_id:continue
        var owned=false
        for unit in logic.units:
            if item.uid in unit.equipment:owned=true
        var button=UI.button(hud.item_text(item)+(" · 已穿戴" if owned else " · 装备"),equip_item.bind(item.uid));button.disabled=not allowed or owned;UI.decorate_content(button,"equipment",logic.content.equipment.bases[item.base-1].id);list.add_child(button)
    page.add_child(UI.button("返回旅程菜单",func():hud.clear_modal();hud.toggle_pause()))

func equip_item(uid):
    hud.game.session.submit({"kind":"equip","unit":hud.gear_unit,"slot":hud.gear_slot,"item":uid})
    hud.game.battle=hud.game.session.logic;hud.game.refresh();show_gear()

func show_character_details():
    if hud.blocks_input() or hud.game.selected<0 or hud.game.session.command_pending or hud.game.presentation_active():return
    if hud.game.battle.units[hud.game.selected].controller!="player":return
    hud.game.clear_move_preview();hud.game.map_touch=-1;hud.clear_modal()
    hud.modal=preload("res://ui/character_details.gd").new();hud.modal.hud=hud;hud.modal.actor=hud.game.selected;hud.modal.z_index=100
    hud.modal.canceled.connect(hud.clear_modal);hud.root.add_child(hud.modal);hud.refresh_story()
