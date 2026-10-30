extends RefCounted
# Skill / item picker panel: entries, legality reasons and activation.
# It owns no nodes; every screen object lives on the HUD it is given, which keeps
# battle_hud.gd from growing into the whole UI.

const UI=preload("res://ui/style.gd")
const ContentPicker=preload("res://ui/content_picker.gd")

var hud


func _init(owner) -> void:
    hud = owner

func ability_description(ability):
    var parts=["目标："+{"self":"自身","ally":"同阵营","enemy":"其他阵营"}[ability.target],"额外射程 +%d · 法力 %d · 冷却 %d 回合"%[ability.reach_bonus,ability.mp_cost,ability.cooldown]]
    for effect in ability.effects:
        parts.append(("治疗 %d"%effect.value if effect.op=="heal" else "攻击 +%d（%s）"%[effect.value,"法术" if ability.damage_type=="magic" else "物理"])+(" · 半径 %d"%effect.radius if effect.radius>0 else ""))
    parts.append("暴击 %d%% · 倍率 %d%%"%[ability.get("crit_chance",0),ability.get("crit_multiplier",150)])
    if ability.stationary:parts.append("移动后需行咒装备方可施放")
    return "\n".join(parts)

func ability_reason(u,ability,index):
    if u.acted:return "本回合行动已用尽"
    if u.mp<ability.mp_cost:return "法力不足"
    if u.cooldowns[index]>0:return "冷却剩余 %d 回合"%u.cooldowns[index]
    if ability.charges>0 and u.charges[index]==0:return "使用次数已耗尽"
    if ability.stationary and u.moves_used>0 and not u.get("mobile_cast",false):return "移动后不可施放"
    return ""

func picker_entries(kind):
    var result=[]
    if hud.game.selected<0 or hud.game.selected>=hud.game.battle.units.size():return result
    var u=hud.game.battle.units[hud.game.selected]
    var data=hud.game.battle.content
    if kind=="skill":
        for i in range(data.abilities.size()):
            var ability=data.abilities[i]
            if ability.id=="attack" or ability.id not in u.abilities:continue
            var summary="MP %d · 冷却 %d"%[ability.mp_cost,u.cooldowns[i]]
            if ability.charges>0:summary+=" · 余%d"%u.charges[i]
            result.append({"id":ability.id,"name":ability.name,"summary":summary,"compact":"MP%d · 冷%d"%[ability.mp_cost,u.cooldowns[i]],"description":ability_description(ability),"reason":ability_reason(u,ability,i)})
    else:
        for i in range(data.consumables.size()):
            var item=data.consumables[i];var reason="没有库存" if hud.game.battle.supplies[i]<=0 else ""
            var description="技能定义不可用";var matched=false
            for j in range(data.abilities.size()):
                var ability=data.abilities[j]
                if ability.id!=item.ability:continue
                matched=true;description=ability_description(ability)
                if reason.is_empty():reason=ability_reason(u,ability,j)
                break
            if not matched:reason="技能定义不可用"
            result.append({"id":item.id,"name":item.name,"summary":"数量 ×%d"%hud.game.battle.supplies[i],"description":description,"reason":reason})
    return result

func picker_current():
    return not hud.picker_context.is_empty() and hud.game.session==hud.picker_context.session and hud.game.session.connection_generation==hud.picker_context.generation and hud.game.selected==hud.picker_context.actor and hud.game.selected>=0 and hud.game.selected<hud.game.battle.units.size() and hud.game.battle.units[hud.game.selected].id==hud.picker_context.id and hud.game.battle.step==hud.picker_context.step and hud.game.battle.outcome=="playing" and not hud.game.presentation_active()

func show_picker(kind):
    if hud.blocks_input() or hud.game.selected<0:return
    hud.game.clear_move_preview();hud.clear_modal()
    var u=hud.game.battle.units[hud.game.selected]
    hud.picker_context={"session":hud.game.session,"generation":hud.game.session.connection_generation,"actor":hud.game.selected,"id":u.id,"step":hud.game.battle.step}
    hud.modal=ContentPicker.new();hud.modal.bottom_limit=hud.dock.picker_bottom_limit;hud.modal.category=kind;hud.modal.title=u.name+" · 技能" if kind=="skill" else "共用行囊 · 道具";hud.modal.entries=picker_entries(kind);hud.modal.z_index=100
    hud.modal.activated.connect(activate_picker.bind(kind));hud.modal.canceled.connect(hud.clear_modal);hud.root.add_child(hud.modal);hud.refresh_story()

func activate_picker(id,kind):
    var allowed=picker_current() and hud.game.battle.usable(hud.game.selected)
    var entry_found=false
    if allowed:
        for entry in picker_entries(kind):
            if entry.id==id:entry_found=entry.reason.is_empty();break
    hud.clear_modal()
    if allowed and entry_found and not hud.game.targeting_locked():
        hud.game.select_mode(("ability:" if kind=="skill" else "item:")+id)

func show_abilities():show_picker("skill")

func choose_ability(id):
    hud.clear_modal();hud.game.select_mode("ability:"+id)

func item_text(item):
    var data=hud.game.battle.content.equipment
    var base=data.bases[item.base-1]
    var text=["普通","魔法","稀有","独特"][item.quality]+" · "+(base.unique_name if item.quality==3 else base.name)+" #"+str(item.uid)
    var bonuses=[]
    for key in base.stats:bonuses.append(str(key)+" +"+str(base.stats[key]))
    for entry in item.affixes:
        var affix=data.affixes[entry.index-1]
        bonuses.append(affix.name+(" +"+str(entry.value) if affix.stat!="none" else ""))
    if not bonuses.is_empty():text+="\n"+" / ".join(bonuses)
    return text

func show_items():show_picker("item")

func choose_item(id):hud.clear_modal();hud.game.select_mode("item:"+id)

func scroll_list(parent):
    var scroll=ScrollContainer.new();scroll.custom_minimum_size=Vector2(550,280);parent.add_child(scroll)
    var list=UI.column(scroll,8);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;return list
