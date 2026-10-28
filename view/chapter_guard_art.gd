extends RefCounted
# Built-in chapter-three identities only. No rule/schema additions or mod paths.
const ROOT='res://assets/characters/chapter3/'
const IDS=['rodd','vera']
const DIRECTIONS=['front_left','front_right','back_left','back_right']
static var cache={}
static var attempted=false
static func point(value,expected):
    if not value is Array or value.size()!=2:return false
    for n in value:
        if not (n is float or n is int) or not is_finite(n):return false
    return Vector2(value[0],value[1]).is_equal_approx(expected)
static func texture(path,size):
    if not path is String or path.contains('..') or path.contains(':') or path.contains('\\') or path.begins_with('/') or not path.ends_with('.png'):return null
    if not ResourceLoader.exists(ROOT+path):return null
    var t=load(ROOT+path)
    return t if t is Texture2D and t.get_size()==size else null
static func profile(id):
    if id not in IDS:return {}
    if not attempted:
        attempted=true
        var m=FileAccess.open(ROOT+'map_contract.json',FileAccess.READ);var b=FileAccess.open(ROOT+'battle_contract.json',FileAccess.READ)
        if m and b and m.get_length()<32768 and b.get_length()<32768:cache=decode(JSON.parse_string(m.get_as_text()),JSON.parse_string(b.get_as_text()))
        if cache.is_empty():push_warning('Chapter guard art unavailable; retaining generic diagnostic fallback')
    return cache.get(id,{})
static func decode(m,b):
    if not m is Dictionary or not b is Dictionary or m.get('schema_version')!=1 or b.get('schema_version')!=1:return {}
    if not point(m.get('map_canvas'),Vector2(128,128)) or not point(m.get('foot_anchor'),Vector2(64,120)) or not point(m.get('portrait_canvas'),Vector2(512,512)):return {}
    if not point(b.get('frame_size'),Vector2(192,160)) or not point(b.get('foot_anchor'),Vector2(96,144)):return {}
    if not m.get('characters') is Dictionary or not b.get('characters') is Dictionary or not b.get('contact_points') is Dictionary:return {}
    var result={}
    for id in IDS:
        var md=m.characters.get(id);var bd=b.characters.get(id);var geo=b.contact_points.get(id)
        if not md is Dictionary or not bd is Dictionary or not geo is Dictionary:return {}
        if not md.get('map_static') is Dictionary or not bd.get('frames') is Array or bd.frames.size()!=4 or not bd.get('defender') is Dictionary:return {}
        if bd.get('facing')!='right' or bd.get('tick_ms')!=60:return {}
        var portrait=texture(md.get('portrait'),Vector2(512,512));var directions={}
        if portrait==null:return {}
        for dir in DIRECTIONS:
            var t=texture(md.map_static.get(dir),Vector2(128,128))
            if t==null:return {}
            directions[dir]=t
        var poses=[]
        for frame in bd.frames:
            if not frame is Dictionary:return {}
            var t=texture(frame.get('path'),Vector2(192,160))
            if t==null:return {}
            poses.append(t)
        var timeline=bd.get('timeline_24ticks')
        if not timeline is Array or timeline.size()!=24:return {}
        for n in timeline:
            if not (n is int or n is float) or not is_finite(n) or n!=floor(n) or n<0 or n>=4:return {}
        var release=9 if id=='rodd' else 12
        if bd.get('release_tick')!=release or bd.get('contact_tick')!=(9 if id=='rodd' else 16):return {}
        for key in (['weapon_tip','hurt_point'] if id=='rodd' else ['release_point','projectile_tip','hurt_point']):
            var v=geo.get(key)
            if not v is Array or v.size()!=2:return {}
            for axis in range(2):
                if not (v[axis] is int or v[axis] is float) or not is_finite(v[axis]) or v[axis]<0 or v[axis]>=[192,160][axis]:return {}
        if geo.get('hurt_radius')!=16:return {}
        var defender={}
        for state in ['idle','hit','recover']:
            var t=texture(bd.defender.get(state),Vector2(192,160))
            if t==null:return {}
            defender[state]=t
        result[id]={'portrait_path':ROOT+md.portrait,'map':directions,'actor_set':{'textures':poses,'timeline':timeline,'tick_seconds':0.06,'release':release,'melee':id=='rodd'},'defender_set':defender,'contact':geo.duplicate(true)}
    return result
