extends RefCounted
# Optional presentation assets. No rule state, event generation, or transforms.
const MANIFEST="res://assets/animations/idle_cycles.json"
var clips={"map":{},"battle":{}}
var errors=[]
func _init(path=MANIFEST):
    if not FileAccess.file_exists(path):return
    var file=FileAccess.open(path,FileAccess.READ)
    if file.get_length()>65536:errors.append("idle manifest exceeds 64 KiB");return
    configure(JSON.parse_string(file.get_as_text()))
func configure(data):
    clips={"map":{},"battle":{}};errors.clear()
    if not data is Dictionary or data.get("version")!=1:errors.append("idle manifest version must be 1");return
    for domain in ["map","battle"]:
        var entries=data.get(domain,{})
        if not entries is Dictionary or entries.size()>128:errors.append(domain+": invalid entries");continue
        for key in entries:
            var clip=decode(entries[key],Vector2i(96,128) if domain=="map" else Vector2i(192,160))
            if clip.is_empty():errors.append(domain+":"+str(key)+": invalid clip; using original idle")
            else:clips[domain][key]=clip
func decode(spec,canvas):
    if not spec is Dictionary:return {}
    var paths=spec.get("frames",[]);var durations=spec.get("frame_ms",[])
    if not paths is Array or paths.is_empty() or paths.size()>32:return {}
    if not durations is Array or durations.size()!=paths.size():return {}
    var textures=[];var seconds=[];var total=0.0
    for i in range(paths.size()):
        var path=paths[i];var duration=durations[i]
        if not path is String or not path.begins_with("assets/") or path.contains("..") or path.contains("\\") or not path.ends_with(".png"):return {}
        if not (duration is int or duration is float) or not is_finite(duration) or duration<40 or duration>2000:return {}
        if not ResourceLoader.exists("res://"+path):return {}
        var texture=load("res://"+path)
        if not texture is Texture2D or Vector2i(texture.get_size())!=canvas:return {}
        textures.append(texture);seconds.append(float(duration)/1000.0);total+=seconds[-1]
    return {"textures":textures,"seconds":seconds,"duration":total}
func sample(domain,key,time,fallback,reduced=false):
    var clip=clips.get(domain,{}).get(key,{})
    if clip.is_empty():return fallback
    var t=0.0 if reduced else fposmod(maxf(0,time),clip.duration)
    for i in range(clip.textures.size()):
        if t<clip.seconds[i]:return clip.textures[i]
        t-=clip.seconds[i]
    return clip.textures[0]
