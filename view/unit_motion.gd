extends Node
# Pure presentation. No rule calls, command submission, RNG, or hash mutation.
var game
# Registered three-pose walk; all other directions retain static neutral.
var walk_library=preload("res://view/walk_library.gd").shared()
var speed=1.0
var motions={}
var last_step=-1
const WORLD_SPEED=1.0
func active():return not motions.is_empty()
func consume(step,events):
    if step==last_step:return
    finish(false);last_step=step
    for event in events:
        if event.get("kind")!="move":continue
        for i in range(game.battle.units.size()):
            var u=game.battle.units[i]
            if u.id!=event.actor:continue
            var path=event.get("path",[])
            if path is Array and path.size()>=2:
                motions[u.id]={"index":i,"path":path,"elapsed":0.0,"role":u.role,"segment":0,"distance":0.0,"travelled":0.0}
                reset_idle_phase(u.id)
                var first=path[0];game.figures[i].position=Vector3(first.x,game.figure_height(i),first.y)
                var next=path[1]
                var direction=game.projected_facing(Vector2i(first.x,first.y),Vector2i(next.x,next.y),game.iso_roles.has(u.role))
                game.facing[u.id]=direction
                game.figures[i].texture=game.map_motion_neutral_texture(i,direction)
func _process(delta):advance(delta)
func advance(delta):
    if motions.is_empty():return
    for id in motions.keys():
        var motion=motions[id];var i=motion.index
        if i>=game.battle.units.size():
            motions.erase(id);continue
        var remaining=maxf(0,delta)*clampf(speed,0,8)
        motion.elapsed+=remaining
        while remaining>0 and motion.segment<motion.path.size()-1:
            var start=Vector2i(motion.path[motion.segment].x,motion.path[motion.segment].y)
            var end=Vector2i(motion.path[motion.segment+1].x,motion.path[motion.segment+1].y)
            var direction=game.projected_facing(start,end,game.iso_roles.has(motion.role))
            var velocity=WORLD_SPEED*game.character_scale
            var travel=minf(1.0-motion.distance,remaining*velocity)
            motion.distance+=travel
            remaining=maxf(0,remaining-travel/velocity)
            game.facing[id]=direction
            var previous_position=game.figures[i].position
            game.figures[i].position=Vector3(start.x,game.figure_height(i),start.y).lerp(Vector3(end.x,game.figure_height(i),end.y),motion.distance)
            motion.travelled+=previous_position.distance_to(game.figures[i].position)
            game.figures[i].texture=game.map_motion_texture(i,direction,motion.travelled)
            if motion.distance>=0.999999:
                motion.segment+=1;motion.distance=0.0
        if motion.segment>=motion.path.size()-1:
            var end=motion.path[-1]
            settle(id,i,Vector2i(end.x,end.y));motions.erase(id);continue
        game.badges[i].position=game.badge_position(i)
        if game.selected==i:game.selection_ring.position=Vector3(game.figures[i].position.x,0.04,game.figures[i].position.z)

    if motions.is_empty():game.motion_finished()
func reset_idle_phase(id):
    var idle=game.get_node_or_null("MapIdle")
    if idle:idle.clocks[id]=0.0
func settle(id,index,point=null):
    reset_idle_phase(id)
    var u=game.battle.units[index]
    var cell=Vector2i(u.x,u.y) if point==null else point
    if game.selected==index:game.selection_ring.position=Vector3(cell.x,0.04,cell.y)
    game.figures[index].position=Vector3(cell.x,game.figure_height(index),cell.y);game.badges[index].position=game.badge_position(index)
    game.figures[index].texture=game.directional_idle_texture(index,game.facing.get(id,"front"))
func finish(notify=true):
    for id in motions:
        var index=motions[id].index
        if index<game.battle.units.size():settle(id,index)
    motions.clear()
    if notify:game.motion_finished()
