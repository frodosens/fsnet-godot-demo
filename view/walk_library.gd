extends RefCounted
# Presentation-only N/L/N/R clips. One cycle per actual world grid travelled.
const MANIFEST="res://assets/animations/walk_cycles.json"
const DIRECTIONS=["front_left","front_right","back_left","back_right"]
static var shared_library
var clips={}
var errors=[]
static func shared():
    if shared_library==null:shared_library=load("res://view/walk_library.gd").new()
    return shared_library
func _init(path=MANIFEST):
    if not FileAccess.file_exists(path):return
    var file=FileAccess.open(path,FileAccess.READ)
    if file==null:errors.append("walk manifest cannot be opened: "+str(FileAccess.get_open_error()));return
    if file.get_length()>65536:errors.append("walk manifest exceeds 64 KiB");return
    configure(JSON.parse_string(file.get_as_text()))
func configure(data):
    clips.clear();errors.clear()
    if not data is Dictionary or data.get("version")!=1:
        errors.append("walk manifest version must be 1");return
    var entries=data.get("clips")
    if not entries is Dictionary or entries.size()>128:
        errors.append("walk clips must be a bounded dictionary");return
    for key in entries:
        if not valid_key(key):errors.append("walk invalid key: "+str(key));continue
        var clip=decode(entries[key])
        if clip.is_empty():errors.append("walk invalid clip: "+key+"; using static neutral")
        else:clips[key]=clip
func valid_key(key):
    if not key is String:return false
    var parts=key.split(":",true)
    return parts.size()==2 and Content.identifier(parts[0]) and parts[1] in DIRECTIONS
func decode(spec):
    if not spec is Dictionary:return {}
    var distance=spec.get("cycle_distance")
    if not (distance is int or distance is float) or not is_finite(distance) or distance!=1:return {}
    var textures=[]
    for name in ["neutral","left","right"]:
        var path=spec.get(name)
        if not path is String or not path.begins_with("assets/") or path.contains("..") or path.contains(":") or path.contains("\\") or not path.ends_with(".png"):return {}
        if not ResourceLoader.exists("res://"+path):return {}
        var texture=load("res://"+path)
        if not texture is Texture2D or Vector2i(texture.get_size())!=Vector2i(96,128):return {}
        textures.append(texture)
    return {"textures":[textures[0],textures[1],textures[0],textures[2]]}
func matching(id,direction,neutral):
    var key=str(id)+":"+str(direction)
    var clip=clips.get(key,{})
    if clip.is_empty():return {}
    # A reused unit ID with different Mod art must not inherit this pilot.
    if neutral!=clip.textures[0]:
        var message="walk neutral mismatch: "+key+"; using static neutral"
        if message not in errors:errors.append(message)
        return {}
    return clip
func textures_for(id,direction,neutral):
    var clip=matching(id,direction,neutral)
    return [] if clip.is_empty() else clip.textures
func sample(id,direction,distance,neutral):
    var clip=matching(id,direction,neutral)
    if clip.is_empty() or not is_finite(distance) or distance<0:return neutral
    # Numerical accumulation at an exact grid boundary always returns N.
    var phase=0.0 if absf(distance-roundf(distance))<0.00001 else fposmod(distance,1.0)
    return clip.textures[mini(3,int(floor(phase*4.0+0.000001)))]
