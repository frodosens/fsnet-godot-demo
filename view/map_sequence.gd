extends RefCounted
# Optional weighted map-only sequences; old idle/walk libraries remain intact.
const PATH="res://assets/animations/map_sequences.json"
const DIRECTIONS=["front_left","front_right","back_left","back_right"]
static var instance
var profiles={}
var errors=[]
static func shared():
    if instance==null:instance=load("res://view/map_sequence.gd").new()
    return instance
func _init(path=PATH):
    if not FileAccess.file_exists(path):return
    var file=FileAccess.open(path,FileAccess.READ)
    if file==null or file.get_length()>65536:errors.append("map sequence unreadable/oversized");return
    configure(JSON.parse_string(file.get_as_text()))
func configure(data):
    profiles.clear();errors.clear()
    if not data is Dictionary or not data.get("profiles") is Dictionary:
        errors.append("invalid map sequence manifest");return
    var version=data.get("version")
    if not (version is int or version is float) or not is_finite(version) or version!=1:
        errors.append("unsupported map sequence version");return
    if data.profiles.size()>16:errors.append("too many sequence profiles");return
    for id in data.profiles:
        var spec=data.profiles[id]
        if not preload("res://logic/content.gd").identifier(id) or not spec is Dictionary:
            errors.append("invalid sequence profile ID/spec");continue
        var motion_only=spec.get("motion_only",false)
        var idle_only=spec.get("idle_only",false)
        if not idle_only is bool or not motion_only is bool:errors.append("invalid sequence mode flag: "+str(id));continue
        if idle_only and motion_only:errors.append("conflicting sequence modes: "+str(id));continue
        var decoded={};var valid=true
        for direction in DIRECTIONS:
            var item=spec.get(direction)
            if not item is Dictionary:valid=false;break
            var idle_width=item.get("idle_canvas_width",96)
            if not (idle_width is int or idle_width is float) or not is_finite(idle_width) or (idle_width!=96 and idle_width!=128):valid=false;break
            var guard=texture_at(item.get("neutral_guard"),Vector2i(96,128))
            var idle={} if motion_only else decode(item.get("idle"),Vector2i(int(idle_width),128))
            var motion_canvas=Vector2i(128,136) if id=="tessa" else Vector2i(128,128)
            var motion={} if idle_only else decode(item.get("motion"),motion_canvas)
            if guard==null or (not motion_only and idle.is_empty()) or (motion_only and item.has("idle")) or (not idle_only and motion.is_empty()) or (idle_only and item.has("motion")):valid=false;break
            decoded[direction]={"guard":guard,"idle":idle,"motion":motion}
        if valid:profiles[id]=decoded
        else:errors.append("invalid sequence profile: "+str(id)+"; old art retained")
func texture_at(path,canvas):
    if not path is String or not path.begins_with("assets/") or path.contains("..") or path.contains(":") or path.contains("\\") or not path.ends_with(".png"):return null
    if not ResourceLoader.exists("res://"+path):return null
    var texture=load("res://"+path)
    return texture if texture is Texture2D and Vector2i(texture.get_size())==canvas else null
func decode(spec,canvas):
    if not spec is Dictionary:return {}
    var paths=spec.get("frames");var holds=spec.get("ticks");var root=spec.get("root")
    var flip=spec.get("flip_h",false)
    if not flip is bool:return {}
    if not paths is Array or paths.is_empty() or paths.size()>16 or not holds is Array or holds.size()!=paths.size():return {}
    if not root is Array or root.size()!=2:return {}
    for value in root:
        if not (value is int or value is float) or not is_finite(value):return {}
    if root[0]!=canvas.x/2 or root[1]!=120:return {}
    var expected=spec.get("cycle_ticks",38)
    if not (expected is int or expected is float) or not is_finite(expected) or expected!=floor(expected) or expected<1 or expected>384:return {}
    var textures=[];var ends=[];var total=0
    for i in range(paths.size()):
        var tick=holds[i]
        if not (tick is int or tick is float) or not is_finite(tick) or tick!=floor(tick) or tick<1 or tick>38:return {}
        var texture=texture_at(paths[i],canvas)
        if texture==null:return {}
        total+=int(tick);textures.append(texture);ends.append(total)
    if total!=int(expected):return {}
    return {"textures":textures,"ends":ends,"ticks":total,"root":Vector2(root[0],root[1]),"flip_h":flip}
func matching(id,direction,guard):
    var profile=profiles.get(id,{})
    var entry=profile.get(direction,{})
    return entry if not entry.is_empty() and entry.guard==guard else {}
func pick(clip,phase):
    var tick=fposmod(maxf(0,phase),1.0)*clip.ticks
    for i in range(clip.ends.size()):
        if tick<float(clip.ends[i])-0.000001:return clip.textures[i]
    return clip.textures[0]
func idle(id,direction,time,guard,reduced=false):
    var entry=matching(id,direction,guard)
    if entry.is_empty() or entry.idle.is_empty() or not is_finite(time):return guard
    return pick(entry.idle,0.0 if reduced else maxf(0,time)*24.0/entry.idle.ticks)
func motion(id,direction,distance,guard):
    var entry=matching(id,direction,guard)
    if entry.is_empty() or entry.motion.is_empty() or not is_finite(distance) or distance<0:return null
    var phase=0.0 if absf(distance-roundf(distance))<0.00001 else fposmod(distance,1.0)
    return pick(entry.motion,phase)
func textures_for(id,direction,guard):
    var entry=matching(id,direction,guard)
    return [] if entry.is_empty() else entry.idle.get("textures",[])+entry.motion.get("textures",[])
