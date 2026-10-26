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
static func hash_of(data):return JSON.stringify(data,"",true).sha256_text()
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
static func validate(data):
    if not data is Dictionary:return "内容必须是 JSON 对象。"
    for key in data:
        if key not in ["version","id","revision","title","width","height","terrain","units","victory","defeat","story","equipment"]:return "未知内容字段："+str(key)
    if data.get("version")!=1:return "不支持的内容版本。"
    if not identifier(data.get("id")) or not integer(data.get("revision"),1,1000000) or not short_text(data.get("title"),64):return "内容 ID、版本号或标题无效。"
    if not integer(data.get("width"),4,16) or not integer(data.get("height"),4,16):return "地图宽高须为 4–16。"
    if not data.get("terrain") is Array or data.terrain.size()!=data.height:return "地形行数无效。"
    for row in data.terrain:
        if not row is String or row.length()!=data.width:return "地形宽度无效。"
        for cell in row:
            if cell not in ["G","W","B","X"]:return "地形只允许 G 草地 / W 水 / B 桥 / X 障碍。"
    if not data.get("units") is Array or data.units.size()<2 or data.units.size()>16:return "单位数量须为 2–16。"
    var ids={};var occupied={};var allies=0;var enemies=0
    for u in data.units:
        if not u is Dictionary:return "单位必须是对象。"
        for key in u:
            if key not in ["id","name","role","ally","x","y","hp","movement","reach","damage","armor","resist","mp","controller","faction"]:return "未知单位字段："+str(key)
        if not identifier(u.get("id")) or ids.has(u.id) or not short_text(u.get("name"),32) or u.get("role") not in ROLES or not u.get("ally") is bool:return "单位身份/职业无效或重复。"
        if not integer(u.get("x"),0,data.width-1) or not integer(u.get("y"),0,data.height-1):return "单位出生点超出地图。"
        var key=u.y*data.width+u.x
        if data.terrain[u.y][u.x] in ["W","X"] or occupied.has(key):return "出生点不可通行或重叠。"
        for field in ["hp","movement","reach","damage","armor","resist","mp"]:
            var bounds={"hp":[1,200],"movement":[1,8],"reach":[1,8],"damage":[1,40],"armor":[0,20],"resist":[0,20],"mp":[0,30]}[field]
            if not integer(u.get(field),bounds[0],bounds[1]):return "单位属性越界："+field
        if u.has("controller") and u.controller not in ["player","ai"]:return "控制器仅支持 player / ai。"
        if u.has("faction") and not identifier(u.faction):return "阵营 ID 无效。"
        ids[u.id]=true;occupied[key]=true
        if u.ally:allies+=1
        else:enemies+=1
    if allies==0 or enemies==0:return "至少需要一个友方和一个敌方。"
    if not objective_valid(data.get("victory"),ids,data,0) or not objective_valid(data.get("defeat"),ids,data,0):return "目标条件、引用或组合深度无效。"
    var story=data.get("story")
    if not story is Dictionary or story.get("schemaVersion")!=1 or not identifier(story.get("storyId")) or not story.get("characters") is Array or not story.get("events") is Array or story.events.size()>24:return "剧情格式/版本无效。"
    var speakers={"narrator":true};var event_ids={}
    for person in story.characters:
        if not person is Dictionary or not identifier(person.get("id")) or not short_text(person.get("name"),32) or speakers.has(person.id):return "剧情角色身份无效。"
        speakers[person.id]=true
    for event in story.events:
        if not event is Dictionary or not identifier(event.get("id")) or event_ids.has(event.id) or not event.get("lines") is Array or event.lines.size()>32:return "剧情事件无效/重复。"
        if event.get("trigger") not in ["chapter_enter_before_first_player_action","first_player_turn_started_with_round_gte_2","first_player_turn_started_with_round_gte_3","battle_terminal_victory","battle_terminal_defeat","round"]:return "不支持的剧情触发器。"
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
            if not b.get(field) is Array or b[field].size()>16:return "词缀池无效。"
            for id in b[field]:
                if not affix_ids.has(id):return "未知词缀引用。"
        if b.unique_affixes.size()>2 or not short_text(b.get("unique_name"),64):return "独特装备配置无效。"
        base_ids[b.id]=true
    for item in equip.starting:
        if not item is Dictionary or not base_ids.has(item.get("base","")) or not integer(item.get("quality"),0,3) or not item.get("affixes") is Array or item.affixes.size()>2:return "初始物品无效。"
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
    if JSON.stringify(data).to_utf8_buffer().size()>MAX_BYTES:return "内容超过 128 KiB。"
    return ""
static func from_file(path):
    var file=FileAccess.open(path,FileAccess.READ)
    if not file:return {"error":"无法读取文件。"}
    if file.get_length()>MAX_BYTES:return {"error":"内容文件超过 128 KiB。"}
    var data=normalize(parse_json(file.get_as_text()))
    var error=validate(data)
    return {"error":error,"data":data if error.is_empty() else {}}
static func default_content():
    var result=from_file("res://content/default.json")
    assert(result.error.is_empty(),result.error)
    return result.data
static func write_mod(data,overwrite=false):
    var error=validate(data)
    if not error.is_empty():return error
    if data.id=="amber_bridge":return "请为 Mod 使用新 ID，不能覆盖内置战役。"
    DirAccess.make_dir_recursive_absolute("user://mods")
    var path="user://mods/"+data.id+".json"
    if FileAccess.file_exists(path) and not overwrite:return "同名 Mod 已存在，请确认覆盖。"
    var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
    if not file:return "无法写入 Mod。"
    file.store_string(JSON.stringify(data,"  ",true));file.flush();file.close()
    if DirAccess.rename_absolute(path+".tmp",path)!=OK:return "保存失败，原 Mod 保持不变。"
    return ""
