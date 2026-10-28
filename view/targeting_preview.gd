extends RefCounted
# Presentation only: existing Lua preview remains the authority for every target.
static func diamond(center,radius,bounds):
    var cells=[]
    for y in range(maxi(0,center.y-radius),mini(bounds.y,center.y+radius+1)):
        for x in range(maxi(0,center.x-radius),mini(bounds.x,center.x+radius+1)):
            if absi(x-center.x)+absi(y-center.y)<=radius:cells.append(Vector2i(x,y))
    return cells
static func describe(game):
    var out={"active":false,"cast_cells":[],"legal_cells":{},"area_cells":[],"affected_units":[],"hover":Vector2i(-1,-1),"hover_legal":false,"reason":"","summary":""}
    if game.mode=="move" or game.selected<0 or game.hud.action_menu_open or game.targeting_locked():return out
    var battle=game.battle
    if not battle.usable(game.selected):return out
    var actor=battle.units[game.selected];var id="attack";var item_count=-1
    if game.mode.begins_with("ability:"):id=game.mode.trim_prefix("ability:")
    elif game.mode.begins_with("item:"):
        id=""
        for i in range(battle.content.consumables.size()):
            if battle.content.consumables[i].id==game.mode.trim_prefix("item:"):
                id=battle.content.consumables[i].ability;item_count=battle.supplies[i];break
    var ability={};var slot=-1
    for i in range(battle.content.abilities.size()):
        if battle.content.abilities[i].id==id:ability=battle.content.abilities[i];slot=i;break
    if ability.is_empty():return out
    out.active=true;out.friendly=ability.target in ["ally","self"]
    var reach=maxi(0,actor.reach+ability.reach_bonus);var radius=0
    for effect in ability.effects:radius=maxi(radius,effect.radius)
    out.cast_cells=[actor.pos] if ability.target=="self" else diamond(actor.pos,reach,battle.size)
    out.summary="%s · 距离 %d · 影响半径 %d · %s · 法力 %d"%[ability.name,reach,radius,{"self":"自身","ally":"友方","enemy":"敌方"}.get(ability.target,"目标"),ability.mp_cost]
    if ability.charges>0:out.summary+=" · 余 %d 次"%actor.charges[slot]
    if item_count>=0:out.summary+=" · 道具 %d"%item_count
    if actor.acted:out.reason="本回合行动已用尽"
    elif actor.mp<ability.mp_cost:out.reason="法力不足"
    elif actor.cooldowns[slot]>0:out.reason="冷却还需 %d 回合"%actor.cooldowns[slot]
    elif ability.charges>0 and actor.charges[slot]<=0:out.reason="施放次数已用尽"
    elif ability.stationary and actor.moves_used>0 and not actor.get("mobile_cast",false):out.reason="移动后不能施放此技能"
    elif item_count==0:out.reason="道具已用尽"
    for i in range(battle.units.size()):
        if battle.preview_action(game.target_command(i)).get("legal",false):out.legal_cells[battle.units[i].pos]=i
    out.hover=game.pending_target.get("cell",game.target_hover_cell)
    if out.hover.x<0:return out
    var target=battle.at(out.hover)
    out.hover_legal=out.legal_cells.has(out.hover)
    if out.hover_legal:
        out.area_cells=diamond(out.hover,radius,battle.size)
        for unit in battle.units:
            if unit.hp>0 and unit.faction==battle.units[target].faction and unit.pos in out.area_cells:out.affected_units.append(unit.id)
        out.reason="再点同一目标即可施放 · 取消仍可返回"
    elif out.reason.is_empty():
        if target<0:out.reason="请选择单位，空格不能作为目标"
        elif ability.target=="self" and target!=game.selected:out.reason="此技能只能以自身为目标"
        elif ability.target=="enemy" and battle.units[target].faction==actor.faction:out.reason="请选择敌方目标"
        elif ability.target=="ally" and battle.units[target].faction!=actor.faction:out.reason="请选择友方目标"
        elif absi(out.hover.x-actor.pos.x)+absi(out.hover.y-actor.pos.y)>reach:out.reason="超出施法距离"
        else:out.reason="目标被阻挡或技能条件不满足"
    return out
