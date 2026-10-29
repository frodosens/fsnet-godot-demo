extends RefCounted
# Exact admitted unit IDs only. No role/faction matching and no campaign spawns.
const PATH="res://assets/animations/generic_map_library.json"
const Sequence=preload("res://view/map_sequence.gd")
static var cache={}
const NAMES={"generic_soldier_01":"通用士兵","generic_knight_01":"通用重甲兵","generic_beast_01":"通用石兽","generic_caster_01":"通用施法者","generic_archer_01":"通用弓手","generic_bandit_01":"通用山贼"}
static func canonical_id(id):
    var profile=preload("res://logic/presentation_profiles.gd").resolve({"id":id})
    return profile if profile in Sequence.CATALOG_IDS else ""
static func declared(id):return not canonical_id(id).is_empty()
# Data-only editor/chapter query: no role, balance, faction or spawn assignment.
static func templates():
    var result=[]
    for id in Sequence.CATALOG_IDS:result.append({"id":id,"name":NAMES[id],"profile_id":id,"portrait_available":false,"authored_battle_available":false})
    return result
static func profile(id):
    if not declared(id):return {}
    if cache.has(id):return cache[id]
    var canonical=canonical_id(id)
    if canonical!=id:
        var original=profile(canonical)
        if original.is_empty():cache[id]={};return {}
        var loader=Sequence.new("",true)
        loader.profiles[id]=original.library.profiles[canonical]
        cache[id]={"map":original.map,"library":loader,"static_fallback":original.static_fallback}
        return cache[id]
    cache[id]={}
    var file=FileAccess.open(PATH,FileAccess.READ)
    if file==null or file.get_length()>16384:return {}
    var catalog=JSON.parse_string(file.get_as_text())
    if not catalog is Dictionary or catalog.get("version")!=1 or not catalog.get("profiles") is Dictionary:return {}
    var spec=catalog.profiles.get(id)
    if not spec is Dictionary:return {}
    cache[id]=decode_profile(id,spec)
    return cache[id]
static func decode_profile(id,spec,provided_data=null,from_memory=false):
    if id not in Sequence.CATALOG_IDS or not spec is Dictionary:return {}
    var base=spec.get("base","")
    if not base is String or base.contains("..") or base.contains(":") or base.contains("\\"):return {}
    if not base.begins_with("assets/sprites/iso4/"+id+"_") and not base.begins_with("assets/characters/generic/"+id+"/"):return {}
    if spec.get("manifest")!=base+"runtime_manifest.json" or not spec.get("idle") is Dictionary:return {}
    var loader=Sequence.new("",true);var canonical={}
    for d in ["front_left","back_left"]:
        var path=spec.idle.get(d)
        if not path is String or not path.begins_with(base):return {}
        var texture=loader.texture_at(path,Vector2i(160,160))
        if texture==null:return {}
        canonical[d]=texture
    var data=provided_data
    if not from_memory:
        var file2=FileAccess.open("res://"+spec.manifest,FileAccess.READ)
        if file2!=null and file2.get_length()<=65536:data=JSON.parse_string(file2.get_as_text())
    var valid=data is Dictionary and data.get("version")==2 and data.get("profiles") is Dictionary and data.profiles.keys()==[id]
    if valid:valid=data.profiles[id] is Dictionary
    if valid:
        for d in Sequence.DIRECTIONS:
            var entry=data.profiles[id].get(d)
            if not entry is Dictionary or entry.get("neutral_guard")!=spec.idle[d.replace("right","left")]:valid=false;break
            for state in ["idle","motion"]:
                var clip=entry.get(state)
                if not clip is Dictionary or not clip.get("frames") is Array:valid=false;break
                for path in clip.frames:
                    if not path is String or not path.begins_with(base):valid=false;break
            if not valid:break
    if valid:loader.configure(data)
    # Bad gait keeps this identity's own canonical static pose, never a hero image.
    var fallback=not loader.profiles.has(id)
    if fallback:
        var static_spec={"canvas":[160,160]}
        for d in Sequence.DIRECTIONS:
            var path=spec.idle[d.replace("right","left")]
            var clip={"frames":[path],"ticks":[1],"cycle_ticks":1,"root":[80,144],"flip_h":d.ends_with("right")}
            static_spec[d]={"neutral_guard":path,"idle":clip,"motion":clip.duplicate(true)}
        loader.configure({"version":2,"profiles":{id:static_spec}})
    if not loader.profiles.has(id):return {}
    var map={}
    for d in Sequence.DIRECTIONS:map[d]=canonical[d.replace("right","left")]
    return {"map":map,"library":loader,"static_fallback":fallback}
