extends Node
# Pure presentation. No rule calls, command submission, RNG, or hash mutation.
var game
var frames={}
var fps=8.0
var speed=1.0
var motions={}
var last_step=-1
var tile_seconds=0.24
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
            if path is Array and path.size()>=2:
                motions[u.id]={"index":i,"path":path,"elapsed":0.0,"role":u.role}
                var first=path[0];game.figures[i].position=Vector3(first.x,0.63,first.y)
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
        var direction=game.projected_facing(start,end);game.facing[id]=direction
        var phase=fmod(motion.elapsed,tile_seconds)/tile_seconds
        game.figures[i].position=Vector3(start.x,0.63,start.y).lerp(Vector3(end.x,0.63,end.y),phase)
        game.badges[i].position=game.figures[i].position+Vector3(0,0.99,0)
        var textures=frames[motion.role][direction]
        game.figures[i].texture=textures[int(motion.elapsed*fps)%textures.size()]
    if motions.is_empty():game.motion_finished()
func settle(id,index):
    var u=game.battle.units[index]
    game.figures[index].position=Vector3(u.x,0.63,u.y);game.badges[index].position=Vector3(u.x,1.62,u.y)
    var key=id+":"+game.facing.get(id,"front")
    if game.direction_textures.has(key):game.figures[index].texture=game.direction_textures[key]
func finish(notify=true):
    for id in motions:
        var index=motions[id].index
        if index<game.battle.units.size():settle(id,index)
    motions.clear()
    if notify:game.motion_finished()
