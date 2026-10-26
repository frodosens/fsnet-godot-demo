extends Node
# Pure presentation. No rule calls, command submission, RNG, or hash mutation.
var game
var frames={}
var fps=8.0
var speed=1.0
var motions={}
var last_step=-1
var tile_seconds=0.50
func _ready():
    var path="res://assets/sprites/walk/manifest.json"
    if not FileAccess.file_exists(path):return
    var data=JSON.parse_string(FileAccess.get_file_as_string(path))
    if not data is Dictionary:return
    fps=clampf(float(data.get("fps",8)),4,16)
    var characters=data.get("characters",{})
    if not characters is Dictionary:return
    for role in characters:
        var directions={}
        for direction in ["front","back","left","right"]:
            var paths=characters[role].get(direction,[])
            if paths is Dictionary:paths=paths.get("frames",[])
            var textures=[]
            if paths is Array:
                for file in paths:
                    if file is String and file.begins_with("assets/sprites/walk/") and not file.contains("..") and ResourceLoader.exists("res://"+file):textures.append(load("res://"+file))
            if textures.size()>=4:directions[direction]=textures
        if directions.size()==4:frames[role]=directions
    var iso_path="res://assets/sprites/iso4/manifest.json"
    if FileAccess.file_exists(iso_path):
        var iso=JSON.parse_string(FileAccess.get_file_as_string(iso_path))
        if iso is Dictionary:
            for role in game.iso_roles:
                frames.erase(role) # Never combine a new perspective idle with an old flat walk.
                var walking=iso.get("characters",{}).get(role,{}).get("walk",{});var directions={}
                for direction in ["front_left","front_right","back_left","back_right"]:
                    var textures=[]
                    for file in walking.get(direction,[]):
                        if file is String and file.begins_with("assets/sprites/iso4/") and not file.contains("..") and ResourceLoader.exists("res://"+file):textures.append(load("res://"+file))
                    if textures.size()>=4:directions[direction]=textures
                if not directions.is_empty():frames[role]=directions
func active():return not motions.is_empty()
func consume(step,events):
    if step==last_step:return
    finish(false);last_step=step
    for event in events:
        if event.get("kind")!="move":continue
        for i in range(game.battle.units.size()):
            var u=game.battle.units[i]
            if u.id!=event.actor or u.hp<=0 or not frames.has(u.role):continue
            var path=event.get("path",[])
            if path is Array and path.size()>=2 and path_has_frames(u.role,path):
                motions[u.id]={"index":i,"path":path,"elapsed":0.0,"role":u.role}
                var first=path[0];game.figures[i].position=Vector3(first.x,0.63,first.y)
func path_has_frames(role,path):
    # A partial art proof animates only supported paths; never slide a missing pose.
    for segment in range(path.size()-1):
        var start=Vector2i(path[segment].x,path[segment].y)
        var end=Vector2i(path[segment+1].x,path[segment+1].y)
        var direction=game.projected_facing(start,end,game.iso_roles.has(role))
        if not frames.get(role,{}).has(direction):return false
    return true
func _process(delta):advance(delta)
func advance(delta):
    if motions.is_empty():return
    for id in motions.keys():
        var motion=motions[id];var i=motion.index
        if i>=game.battle.units.size() or game.battle.units[i].hp<=0:
            motions.erase(id);continue
        motion.elapsed+=delta*speed
        var segment=int(motion.elapsed/tile_seconds)
        if segment>=motion.path.size()-1:
            settle(id,i);motions.erase(id);continue
        var start=Vector2i(motion.path[segment].x,motion.path[segment].y)
        var end=Vector2i(motion.path[segment+1].x,motion.path[segment+1].y)
        var direction=game.projected_facing(start,end,game.iso_roles.has(motion.role));game.facing[id]=direction
        var phase=fmod(motion.elapsed,tile_seconds)/tile_seconds
        game.figures[i].position=Vector3(start.x,0.63,start.y).lerp(Vector3(end.x,0.63,end.y),phase)
        game.badges[i].position=game.figures[i].position+Vector3(0,0.99,0)
        if game.selected==i:game.selection_ring.position=Vector3(game.figures[i].position.x,0.04,game.figures[i].position.z)
        var textures=frames[motion.role][direction]
        game.figures[i].texture=textures[int(motion.elapsed*fps)%textures.size()]
    if motions.is_empty():game.motion_finished()
func settle(id,index):
    var u=game.battle.units[index]
    if game.selected==index:game.selection_ring.position=Vector3(u.x,0.04,u.y)
    game.figures[index].position=Vector3(u.x,0.63,u.y);game.badges[index].position=Vector3(u.x,1.62,u.y)
    var key=id+":"+game.facing.get(id,"front")
    if game.direction_textures.has(key):game.figures[index].texture=game.direction_textures[key]
func finish(notify=true):
    for id in motions:
        var index=motions[id].index
        if index<game.battle.units.size():settle(id,index)
    motions.clear()
    if notify:game.motion_finished()
