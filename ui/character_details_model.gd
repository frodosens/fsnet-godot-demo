extends RefCounted
# Read-only presentation adapter. Equipment previews execute authoritative Lua
# against a separate snapshot; the live session is never mutated here.
const Runtime=preload("res://logic/runtime.gd")
const SLOTS=["main_hand","off_hand","head","body","hands","feet","neck","ring","ring"]
const SLOT_NAMES=["主手","副手","头部","身体","双手","双脚","项链","戒指一","戒指二"]
const STAT_NAMES={"hp":"当前生命","max_hp":"生命上限","mp":"当前法力","max_mp":"法力上限","damage":"物理攻击","spell_bonus":"法术加成","armor":"护甲","resist":"抗性","movement":"移动距离","reach":"攻击距离","move_actions":"每回合移动次数","mobile_cast":"移动施法"}
var cached_key=""
var cached_preview={}

func valid_actor(logic,index):
    return index>=0 and index<logic.units.size() and logic.units[index].controller=="player"

func stats(unit):
    var result=[]
    for key in STAT_NAMES:
        if unit.has(key):result.append({"key":key,"name":STAT_NAMES[key],"value":unit[key]})
    return result

func equipment_reason(logic,index,pending=false):
    if not valid_actor(logic,index):return "没有可整备的玩家角色"
    if pending:return "正在同步，请稍后再试"
    if not logic.preparation and logic.outcome=="playing":return "战斗中装备锁定；整备或结算后可更换"
    return ""

func inventory(logic,index,slot):
    var result=[]
    if not valid_actor(logic,index) or slot<0 or slot>=SLOTS.size():return result
    for item in logic.inventory:
        var base=logic.content.equipment.bases[item.base-1]
        if base.slot!=SLOTS[slot]:continue
        var owner=""
        for unit in logic.units:
            if item.uid in unit.equipment:owner=unit.name;break
        result.append({"uid":item.uid,"base_id":base.id,"name":base.unique_name if item.quality==3 else base.name,"quality":item.quality,"owner":owner,"equipped":logic.units[index].equipment[slot]==item.uid,"item":item.duplicate(true)})
    return result

func preview_equipment(logic,index,slot,uid):
    var reason=equipment_reason(logic,index)
    if not reason.is_empty():return {"allowed":false,"reason":reason,"changes":[]}
    if slot<0 or slot>=SLOTS.size():return {"allowed":false,"reason":"无效装备槽位","changes":[]}
    var snapshot=logic.snapshot()
    # Content is immutable per Runtime; hash covers content plus all authoritative state.
    var key=logic.content_hash+":"+snapshot.sha256_text()+":"+str(index)+":"+str(slot)+":"+str(uid)
    if key==cached_key:return cached_preview.duplicate(true)
    var sandbox=Runtime.new(logic.content)
    var allowed=sandbox.restore(snapshot)
    if allowed:allowed=sandbox.apply_command({"kind":"equip","unit":index,"slot":slot,"item":uid,"step":logic.step+1})
    var changes=[]
    if allowed:
        var before=logic.units[index];var after=sandbox.units[index]
        for field in STAT_NAMES:
            if before.has(field) and after.has(field) and before[field]!=after[field]:
                changes.append({"key":field,"name":STAT_NAMES[field],"before":before[field],"after":after[field]})
    cached_key=key
    cached_preview={"allowed":allowed,"reason":"" if allowed else "装备不匹配、已被占用或操作已失效","changes":changes}
    return cached_preview.duplicate(true)

func progression(unit):
    for field in ["level","xp","xp_floor","xp_next"]:
        if not unit.has(field):return {"available":false}
    var required=maxi(0,int(unit.xp_next)-int(unit.xp_floor))
    return {"available":true,"level":int(unit.level),"total":int(unit.xp),"current":maxi(0,int(unit.xp)-int(unit.xp_floor)),"required":required,"capped":required==0}
