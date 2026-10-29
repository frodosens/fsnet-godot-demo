extends RefCounted
# Data-only mods. No script evaluation, resource paths, or writes beneath res://.
const MAX_BYTES=131072
const ROLES=["knight","archer","mage","raider","scout","brute"]
const STATS=["physical","spell","armor","resist","hp"]
const EFFECTS=["none","move_action_plus1","mobile_cast"]
const SLOTS=["main_hand","off_hand","head","body","hands","feet","neck","ring"]
static func parse_json(text):
    var parser=JSON.new()
    if parser.parse(text)!=OK:return null
    return parser.data
static func normalize(value,depth=0):
    if depth>12:return null
    if value is float:
        if not is_finite(value) or value!=floor(value) or abs(value)>1000000000:return null
        return int(value)
    if value is Dictionary:
        var result={}
        for key in value:result[str(key)]=normalize(value[key],depth+1)
        return result
    if value is Array:
        var result=[]
        for item in value:result.append(normalize(item,depth+1))
        return result
    return value
const Profiles=preload("res://logic/presentation_profiles.gd")
const DEFINITION_FIELDS=["id","name","role","hp","movement","reach","damage","armor","resist","mp","abilities","skill_id","presentation_ref"]
const INSTANCE_FIELDS=["id","template_ref","name","presentation_ref","x","y","ally","controller","faction","policy","leash","escort"]
static func expand(data):
    if not data is Dictionary:return {"error":"内容必须是对象。","data":{}}
    if data.get("version")!=2:
        # Legacy records retain their exact bytes; new explicit references still
        # pass admission even when an expanded save/config enters Runtime directly.
        var issue=""
        if data.get("units") is Array:
            for u in data.units:
                if u is Dictionary and (u.has("template_ref") or u.has("presentation_ref")):
                    issue=validate(data);break
        return {"error":issue,"data":data.duplicate(true) if issue.is_empty() else {}}
    if JSON.stringify(data).to_utf8_buffer().size()>MAX_BYTES:return {"error":"模板内容超过 128 KiB。","data":{}}
    if not data.get("unit_definitions") is Array or data.unit_definitions.is_empty() or data.unit_definitions.size()>16 or not data.get("units") is Array or data.units.size()<2 or data.units.size()>16:return {"error":"模板或实例列表无效。","data":{}}
    var definitions={};var used={};var result=data.duplicate(true);result.version=1;result.erase("unit_definitions");result.units=[]
    for definition in data.unit_definitions:
        if not definition is Dictionary or not identifier(definition.get("id")) or definitions.has(definition.id):return {"error":"模板 ID 无效或重复。","data":{}}
        for key in definition:
            if key not in DEFINITION_FIELDS:return {"error":"模板含非法字段："+str(key),"data":{}}
        if not Profiles.allowed(definition.get("presentation_ref","")):return {"error":"模板表现引用不在许可表。","data":{}}
        definitions[definition.id]=definition
    for instance in data.units:
        if not instance is Dictionary or not definitions.has(instance.get("template_ref","")):return {"error":"未知单位模板。","data":{}}
        for key in instance:
            if key not in INSTANCE_FIELDS:return {"error":"实例不允许覆盖模板属性："+str(key),"data":{}}
        var unit=definitions[instance.template_ref].duplicate(true)
        unit.erase("id")
        for key in instance:unit[key]=instance[key].duplicate(true) if instance[key] is Array or instance[key] is Dictionary else instance[key]
        used[instance.template_ref]=true;result.units.append(unit)
    if used.size()!=definitions.size():return {"error":"存在未使用的单位模板。","data":{}}
    var issue=validate(result)
    return {"error":issue,"data":result if issue.is_empty() else {}}
static func freeze(value):
    if value is Dictionary:
        for key in value:freeze(value[key])
        value.make_read_only()
    elif value is Array:
        for item in value:freeze(item)
        value.make_read_only()
static func hash_of(data):
    var expanded=expand(data)
    return JSON.stringify(expanded.data,"",true).sha256_text() if expanded.error.is_empty() else ""
static func identifier(value):
    if not value is String or value.is_empty() or value.length()>40:return false
    for c in value:
        if not (c>="a" and c<="z" or c>="0" and c<="9" or c=="_" or c=="-"):return false
    return true
static func integer(value,lo,hi):return value is int and value>=lo and value<=hi
static func short_text(value,limit=256):return value is String and not value.is_empty() and value.length()<=limit
static func stats_valid(value):
    if not value is Dictionary:return false
    for key in value:
        if key not in STATS or not integer(value[key],0,20):return false
    return true
static func objective_valid(goal,ids,data,depth):
    if depth>3 or not goal is Dictionary:return false
    match goal.get("kind"):
        "all","any":
            if not goal.get("children") is Array or goal.children.is_empty() or goal.children.size()>4:return false
            for child in goal.children:
                if not objective_valid(child,ids,data,depth+1):return false
            return true
        "defeat_all","all_allies":return true
        "survive":return integer(goal.get("round"),2,99)
        "protect":return ids.has(goal.get("unit",""))
        "reach":return ids.has(goal.get("unit","")) and integer(goal.get("x"),0,data.width-1) and integer(goal.get("y"),0,data.height-1) and data.terrain[goal.y][goal.x] not in ["W","X"]
    return false
static func array_unique_count(values):
    var unique={}
    for value in values:unique[str(value)]=true
    return unique.size()
static func bridge_cost(value,depth=0):
    if depth>12:return 131073
    var cost=16
    if value is String or value is StringName:return cost+str(value).to_utf8_buffer().size()
    if value is Dictionary:
        if value.size()>32:return 131073
        for key in value:
            if not key is String and not key is StringName:return 131073
            cost+=bridge_cost(key,depth+1)+bridge_cost(value[key],depth+1)
            if cost>131072:return cost
    elif value is Array:
        if value.size()>256:return 131073
        for item in value:
            cost+=bridge_cost(item,depth+1)
            if cost>131072:return cost
    elif value!=null and not value is int and not value is bool:return 131073
    return cost
static func validate(data):
    if not data is Dictionary:return "内容必须是 JSON 对象。"
    if data.get("version")==2:return expand(data).error
    for key in data:
        if key not in ["version","id","revision","title","width","height","terrain","units","victory","defeat","story","equipment","abilities","consumables"]:return "未知内容字段："+str(key)
    if data.get("version")!=1:return "不支持的内容版本。"
    if not identifier(data.get("id")) or not integer(data.get("revision"),1,1000000) or not short_text(data.get("title"),64):return "内容 ID、版本号或标题无效。"
    if not integer(data.get("width"),4,16) or not integer(data.get("height"),4,16):return "地图宽高须为 4–16。"
    if not data.get("terrain") is Array or data.terrain.size()!=data.height:return "地形行数无效。"
    for row in data.terrain:
        if not row is String or row.length()!=data.width:return "地形宽度无效。"
        for cell in row:
            if cell not in ["G","W","B","X","D"]:return "地形只允许 G 草地 / D 土路 / W 水 / B 桥 / X 障碍。"
    if not data.get("units") is Array or data.units.size()<2 or data.units.size()>16:return "单位数量须为 2–16。"
    var ability_ids={}
    if not data.get("abilities") is Array or data.abilities.is_empty() or data.abilities.size()>16:return "技能数量须为 1–16。"
    for ability in data.abilities:
        if not ability is Dictionary or not identifier(ability.get("id")) or ability_ids.has(ability.id) or not short_text(ability.get("name"),32):return "技能 ID 或名称无效。"
        if ability.get("target") not in ["self","ally","enemy"] or not ability.get("stationary") is bool:return "技能目标或静止限制无效。"
        if ability.get("damage_type") not in ["physical","magic"]:return "伤害类型无效。"
        if not integer(ability.get("crit_chance",0),0,100) or not integer(ability.get("crit_multiplier",150),100,300):return "暴击概率或倍率越界。"
        if ability.has("los") and not ability.los is bool:return "视线要求无效。"
        for field in ["reach_bonus","mp_cost","cooldown","charges"]:
            if not integer(ability.get(field),0,8):return "技能消耗或冷却越界。"
        if not ability.get("effects") is Array or ability.effects.is_empty() or ability.effects.size()>4:return "技能效果数量无效。"
        for effect in ability.effects:
            if not effect is Dictionary or effect.get("op") not in ["damage","heal"] or not integer(effect.get("value"),0,20) or not integer(effect.get("radius"),0,2):return "技能效果不在许可表或越界。"
        ability_ids[ability.id]=true
    if not data.get("consumables") is Array or data.consumables.size()>16:return "消耗品表无效。"
    var consumable_ids={}
    for item in data.consumables:
        if not item is Dictionary or not identifier(item.get("id")) or consumable_ids.has(item.id) or not short_text(item.get("name"),32) or not ability_ids.has(item.get("ability","")) or not integer(item.get("count"),0,99):return "消耗品引用或数量无效。"
        consumable_ids[item.id]=true
    var ids={};var occupied={};var allies=0;var enemies=0
    for u in data.units:
        if not u is Dictionary:return "单位必须是对象。"
        for key in u:
            if key not in ["id","name","role","ally","x","y","hp","movement","reach","damage","armor","resist","mp","controller","faction","abilities","skill_id","policy","leash","escort","template_ref","presentation_ref"]:return "未知单位字段："+str(key)
        if u.has("template_ref") and not identifier(u.template_ref):return "模板 ID 无效。"
        if u.has("presentation_ref") and not Profiles.allowed(u.presentation_ref):return "表现引用不在许可表。"
        if not identifier(u.get("id")) or ids.has(u.id) or not short_text(u.get("name"),32) or u.get("role") not in ROLES or not u.get("ally") is bool:return "单位身份/职业无效或重复。"
        if not integer(u.get("x"),0,data.width-1) or not integer(u.get("y"),0,data.height-1):return "单位出生点超出地图。"
        var key=u.y*data.width+u.x
        if data.terrain[u.y][u.x] in ["W","X"] or occupied.has(key):return "出生点不可通行或重叠。"
        for field in ["hp","movement","reach","damage","armor","resist","mp"]:
            var bounds={"hp":[1,200],"movement":[1,8],"reach":[1,8],"damage":[1,40],"armor":[0,20],"resist":[0,20],"mp":[0,30]}[field]
            if not integer(u.get(field),bounds[0],bounds[1]):return "单位属性越界："+field
        if u.has("policy") and u.policy not in ["offensive","defensive","support","escort"]:return "未知 AI 策略。"
        if u.has("leash") and not integer(u.leash,1,16):return "AI 活动半径无效。"
        if u.has("controller") and u.controller not in ["player","ai"]:return "控制器仅支持 player / ai。"
        if u.has("faction") and not identifier(u.faction):return "阵营 ID 无效。"
        if not u.get("abilities") is Array or u.abilities.is_empty() or u.abilities.size()>8:return "单位技能列表无效。"
        var known={}
        for id in u.abilities:
            if not ability_ids.has(id) or known.has(id):return "单位技能引用无效或重复。"
            known[id]=true
        if not known.has("attack") or not known.has(u.get("skill_id","")):return "单位缺少普攻或默认技能。"
        ids[u.id]=true;occupied[key]=true
        if u.ally:allies+=1
        else:enemies+=1
    for u in data.units:
        if u.get("policy")=="escort" and (not ids.has(u.get("escort","")) or u.escort==u.id):return "护送 AI 目标无效。"
    if allies==0 or enemies==0:return "至少需要一个友方和一个敌方。"
    if not objective_valid(data.get("victory"),ids,data,0) or not objective_valid(data.get("defeat"),ids,data,0):return "目标条件、引用或组合深度无效。"
    var story=data.get("story")
    if not story is Dictionary or story.get("schemaVersion")!=1 or not identifier(story.get("storyId")) or not story.get("characters") is Array or not story.get("events") is Array or story.events.size()>24:return "剧情格式/版本无效。"
    if not identifier(story.get("chapterId")) or not short_text(story.get("chapterTitle"),96):return "剧情章节 ID 或标题无效。"
    var speakers={"narrator":true};var event_ids={}
    for person in story.characters:
        if not person is Dictionary or not identifier(person.get("id")) or not short_text(person.get("name"),32) or speakers.has(person.id):return "剧情角色身份无效。"
        speakers[person.id]=true
    for event in story.events:
        if not event is Dictionary or not identifier(event.get("id")) or event_ids.has(event.id) or not event.get("lines") is Array or event.lines.size()>32:return "剧情事件无效/重复。"
        if event.get("trigger") not in ["chapter_enter_before_first_player_action","first_player_turn_started_with_round_gte_2","first_player_turn_started_with_round_gte_3","battle_terminal_victory","battle_terminal_defeat","round","campaign_finish"]:return "不支持的剧情触发器。"
        if event.trigger=="round" and not integer(event.get("round"),1,99):return "剧情回合阈值无效。"
        for line in event.lines:
            if not line is Dictionary or not speakers.has(line.get("speaker","")) or not short_text(line.get("text"),500):return "台词或说话人引用无效。"
        event_ids[event.id]=true
    var equip=data.get("equipment")
    if not equip is Dictionary:return "缺少装备定义。"
    for field in ["bases","affixes","sets","starting"]:
        if not equip.get(field) is Array or equip[field].size()>32:return "装备表数量无效。"
    if equip.bases.is_empty():return "至少需要一个底材。"
    var affix_ids={};var base_ids={};var set_ids={}
    for a in equip.affixes:
        if not a is Dictionary or not identifier(a.get("id")) or affix_ids.has(a.id) or not short_text(a.get("name"),32) or a.get("stat") not in STATS+["none"] or a.get("effect") not in EFFECTS:return "词缀 ID/效果不在许可表。"
        if not integer(a.get("minimum"),0,10) or not integer(a.get("maximum"),a.minimum,10):return "词缀数值范围无效。"
        affix_ids[a.id]=true
    for s in equip.sets:
        if not s is Dictionary or not identifier(s.get("id")) or set_ids.has(s.id) or not short_text(s.get("name"),32) or not integer(s.get("pieces"),2,9) or not stats_valid(s.get("stats")):return "套装数据无效。"
        set_ids[s.id]=true
    for b in equip.bases:
        if not b is Dictionary or not identifier(b.get("id")) or base_ids.has(b.id) or not short_text(b.get("name"),32) or b.get("slot") not in SLOTS or not stats_valid(b.get("stats")):return "装备底材无效。"
        if b.get("set_id","")!="" and not set_ids.has(b.set_id):return "未知套装引用。"
        for field in ["affix_pool","unique_affixes"]:
            if not b.get(field) is Array or b[field].size()>16 or b[field].size()!=array_unique_count(b[field]):return "词缀池无效。"
            for id in b[field]:
                if not affix_ids.has(id):return "未知词缀引用。"
        if b.unique_affixes.size()>2 or not short_text(b.get("unique_name"),64):return "独特装备配置无效。"
        base_ids[b.id]=true
    for item in equip.starting:
        if not item is Dictionary or not base_ids.has(item.get("base","")) or not integer(item.get("quality"),0,3) or not item.get("affixes") is Array or item.affixes.size()>2 or item.affixes.size()!=array_unique_count(item.affixes):return "初始物品无效。"
        for id in item.affixes:
            if not affix_ids.has(id):return "初始物品词缀引用无效。"
    var drops=equip.get("drops")
    if not drops is Dictionary or not integer(drops.get("chance"),0,100) or not drops.get("quality_weights") is Array or drops.quality_weights.size()!=4 or not drops.get("base_pool") is Array or drops.base_pool.is_empty():return "掉落表无效。"
    var total=0
    for weight in drops.quality_weights:
        if not integer(weight,0,100):return "品质权重无效。"
        total+=weight
    if total!=100:return "品质权重之和须为 100。"
    for id in drops.base_pool:
        if not base_ids.has(id):return "掉落底材不存在。"
    if bridge_cost({"seed":12345,"content":data})>131072:return "内容超过原生桥接的层级、集合或内存预算。"
    if JSON.stringify(data).to_utf8_buffer().size()>MAX_BYTES:return "内容超过 128 KiB。"
    return ""
static func from_file(path):
    var file=FileAccess.open(path,FileAccess.READ)
    if not file:return {"error":"无法读取文件。"}
    if file.get_length()>MAX_BYTES:return {"error":"内容文件超过 128 KiB。"}
    var data=normalize(parse_json(file.get_as_text()))
    var error=validate(data)
    return {"error":error,"data":expand(data).data if error.is_empty() else {}}
static func default_content():
    var result=from_file("res://content/default.json")
    assert(result.error.is_empty(),result.error)
    return result.data
static func reference_content():
    var result=from_file("res://content/reference_bridge.json")
    assert(result.error.is_empty(),result.error)
    return result.data
static func chapter_two_content():
    var result=from_file("res://content/white_elm_watchhouse.json")
    assert(result.error.is_empty(),result.error)
    return result.data
static func chapter_three_content():
    var result=from_file("res://content/mill_receipts.json")
    assert(result.error.is_empty(),result.error)
    return result.data
static func write_mod(data,overwrite=false):
    var error=validate(data)
    if not error.is_empty():return error
    if data.id in ["amber_bridge","amber_bridge_reference","white_elm_watchhouse","mill_receipts","homeward_01","homeward_02","homeward_03"]:return "请为 Mod 使用新 ID，不能覆盖内置战役。"
    DirAccess.make_dir_recursive_absolute("user://mods")
    var path="user://mods/"+data.id+".json"
    if FileAccess.file_exists(path) and not overwrite:return "同名 Mod 已存在，请确认覆盖。"
    var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
    if not file:return "无法写入 Mod。"
    file.store_string(JSON.stringify(data,"  ",true));file.flush();file.close()
    if DirAccess.rename_absolute(path+".tmp",path)!=OK:return "保存失败，原 Mod 保持不变。"
    return ""
