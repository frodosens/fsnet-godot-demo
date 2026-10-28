extends RefCounted
# Built-in presentation profiles keyed by existing unit ID. No rule/schema fields.
const IDS=["adela","elsbet"]
const ROOT="res://assets/characters/reserve/"
const DIRECTIONS=["front_left","front_right","back_left","back_right"]
# Actual head pixels on the original hurt images at the new staff's y=60 row.
# Only Elsbet's high strike uses these; old torso contacts remain unchanged.
const LEGACY_HEAD_X={"mara":67,"finn":80,"neri":96,"oren":114,"tessa":80,"bram":98}
static var cache={}
static func texture_at(base,path,canvas):
    if not path is String or path.contains("..") or path.contains(":") or path.contains("\\") or path.begins_with("/") or not path.ends_with(".png"):return null
    if not ResourceLoader.exists(base+path):return null
    var texture=load(base+path)
    return texture if texture is Texture2D and texture.get_size()==canvas else null
static func profile(id):
    if id in preload("res://view/chapter_guard_art.gd").IDS:return preload("res://view/chapter_guard_art.gd").profile(id)
    if id not in IDS:return {}
    if cache.has(id):return cache[id]
    cache[id]={}
    var base=ROOT+id+"/";var file=FileAccess.open(base+"manifest.json",FileAccess.READ)
    if not file or file.get_length()>32768:return rejected("manifest unreadable or too large: "+id)
    var data=preload("res://logic/content.gd").normalize(JSON.parse_string(file.get_as_text()))
    cache[id]=decode_profile(data,id,base)
    return cache[id]
static func rejected(reason):
    push_warning("Reserve art fallback: "+reason)
    return {}
# Decode separately so malformed documents can be checked without replacing assets/cache.
static func decode_profile(data,id,base):
    if not data is Dictionary or data.get("schema_version")!=1 or data.get("character_id")!=id:return rejected("invalid manifest identity")
    if not data.get("map") is Dictionary or not data.get("battle") is Dictionary or not data.get("portrait") is Dictionary:return rejected("map/battle/portrait must be objects")
    if not data.map.get("directions") is Dictionary:return rejected("map.directions must be an object")
    if not data.battle.get("frames") is Dictionary:return rejected("battle.frames must be an object")
    if not data.battle.get("geometry") is Dictionary:return rejected("battle.geometry must be an object")
    var portrait=texture_at(base,data.portrait.get("file"),Vector2(512,512))
    if portrait==null:return rejected("invalid portrait texture")
    var directions={}
    for direction in DIRECTIONS:
        var entry=data.map.directions.get(direction)
        if not entry is Dictionary:return rejected("invalid map direction entry: "+direction)
        var texture=texture_at(base,entry.get("file"),Vector2(96,128))
        if texture==null:return rejected("invalid texture entry")
        directions[direction]=texture
    if data.map.get("idle_mode")!="static" or data.map.get("foot_anchor")!=[48,120] or data.battle.get("foot_anchor")!=[96,144] or data.battle.get("facing")!="right":return rejected("invalid map/battle alignment")
    var poses={}
    for key in ["idle_00","idle_01","anticipation","contact","hurt"]:
        var entry=data.battle.frames.get(key+".png")
        if not entry is Dictionary:return rejected("invalid battle frame entry: "+key)
        var texture=texture_at(base,entry.get("file"),Vector2(192,160))
        if texture==null:return rejected("invalid texture entry")
        poses[key]=texture
    var geometry=data.battle.geometry
    for key in ["attack_contact_tip_xy","hurt_body_anchor_xy","hurt_head_anchor_xy"]:
        var point=geometry.get(key)
        if not point is Array or point.size()!=2:return rejected("invalid geometry vector: "+key)
        for axis in range(2):
            if not (point[axis] is float or point[axis] is int) or not is_finite(point[axis]) or point[axis]<0 or point[axis]>=[192,160][axis]:return rejected("invalid geometry coordinate: "+key)
    return {"portrait_path":base+data.portrait.file,"map":directions,"poses":poses,"geometry":geometry}
static func portrait_path(id):
    var art=profile(id)
    return art.portrait_path if not art.is_empty() else "res://assets/portraits/"+id+".png"
