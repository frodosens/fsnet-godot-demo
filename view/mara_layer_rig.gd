extends Node
# Optional presentation-only proof. Composites authored layers; never mutates battle state.
const MANIFEST="res://assets/sprites/layered/knight/back_right/manifest.json"
var game
var viewport:SubViewport
var canvas
var available=false
var config={}
var stride=0.09
var last_error=0.0

static func solve_leg(hip:Vector2,target:Vector2,upper:float,lower:float,bend:float):
    var delta=target-hip;var distance=delta.length()
    var reach=clampf(distance,absf(upper-lower)+0.001,upper+lower-0.001)
    var direction=delta.normalized() if distance>0.001 else Vector2.DOWN
    var ankle=hip+direction*reach
    var angle=acos(clampf((upper*upper+reach*reach-lower*lower)/(2.0*upper*reach),-1,1))
    var knee=hip+direction.rotated(angle*signf(bend))*upper
    return {"knee":knee,"ankle":ankle,"clamp_error":ankle.distance_to(target)}

class LayerCanvas extends Node2D:
    var layers=[]
    var solver:Callable
    var legs={}
    var commands={}
    var stance=0.60
    var lift=2.0
    var pelvis_drop=0.0
    var max_error=0.0
    func pose(cycles,cycle_delta):
        commands.clear();max_error=0
        commands.upper_body={"position":Vector2(0,pelvis_drop),"rotation":0.0,"pivot":Vector2.ZERO}
        for side in ["far","near"]:
            var leg=legs[side];var phase=fposmod(cycles+float(leg.get("phase_offset",0.5 if side=="far" else 0.0)),1.0)
            var shift:Vector2
            if phase<stance:shift=cycle_delta*(stance*0.5-phase)
            else:
                var swing=(phase-stance)/(1.0-stance);var t2=swing*swing;var t3=t2*swing
                var start=-cycle_delta*stance*0.5;var end=cycle_delta*stance*0.5
                var tangent=-cycle_delta*(1.0-stance)
                shift=start*(2*t3-3*t2+1)+tangent*(t3-2*t2+swing)+end*(-2*t3+3*t2)+tangent*(t3-t2)
                shift+=Vector2(0,-lift*pow(sin(PI*swing),2))
            var target=leg.ankle+shift
            var solved=solver.call(leg.hip+Vector2(0,pelvis_drop),target,leg.upper,leg.lower,leg.bend)
            max_error=maxf(max_error,solved.clamp_error)
            commands[side+"_thigh"]={"position":leg.hip+Vector2(0,pelvis_drop),"rotation":(solved.knee-leg.hip-Vector2(0,pelvis_drop)).angle()-(leg.knee-leg.hip).angle(),"pivot":leg.hip}
            commands[side+"_shin"]={"position":solved.knee,"rotation":(solved.ankle-solved.knee).angle()-(leg.ankle-leg.knee).angle(),"pivot":leg.knee}
            # Boot orientation remains authored; it does not inherit the shin's angle.
            commands[side+"_boot"]={"position":solved.ankle,"rotation":0.0,"pivot":leg.ankle}
        queue_redraw()
    func _draw():
        for layer in layers:
            var pose_data=commands.get(layer.name,{"position":Vector2.ZERO,"rotation":0.0,"pivot":Vector2.ZERO})
            draw_set_transform(pose_data.position,pose_data.rotation)
            draw_texture(layer.texture,-pose_data.pivot)
        draw_set_transform(Vector2.ZERO)

func _ready():
    if not FileAccess.file_exists(MANIFEST):return
    var data=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
    if not data is Dictionary or data.get("schema")!=1 or data.get("direction")!="back_right":return
    var dimensions=data.get("canvas",[])
    if not dimensions is Array or dimensions.size()!=2 or Vector2(float(dimensions[0]),float(dimensions[1]))!=Vector2(96,128):return
    var legs={};var layers=[]
    for side in ["near","far"]:
        var raw=data.get("joints",{}).get(side,{})
        var joints={}
        for key in ["hip","knee","ankle","sole"]:
            var value=raw.get("sole_contact_estimate" if key=="sole" else key,[])
            if not value is Array or value.size()!=2:return
            joints[key]=Vector2(float(value[0]),float(value[1]))
            if not Rect2(-16,-16,128,160).has_point(joints[key]):return
        joints.upper=joints.hip.distance_to(joints.knee);joints.lower=joints.knee.distance_to(joints.ankle);joints.bend=signf((joints.ankle-joints.hip).cross(joints.knee-joints.hip));joints.phase_offset=float(raw.get("phase_offset",0))
        if joints.upper<2 or joints.lower<2 or absf(joints.bend)<0.5:return
        legs[side]=joints
    for name in ["upper_body","far_thigh","far_shin","far_boot","near_thigh","near_shin","near_boot"]:
        var authored_name="upperbody" if name=="upper_body" else name
        var raw=data.get("layers",{}).get(authored_name,{})
        var file=raw.get("file","")
        if not file is String or file.is_empty() or file.is_absolute_path() or ".." in file or file.get_extension()!="png":return
        var path=MANIFEST.get_base_dir()+"/"+file
        if not ResourceLoader.exists(path):return
        var texture=load(path)
        if not texture is Texture2D or texture.get_size()!=Vector2(96,128):return
        layers.append({"name":name,"texture":texture,"z":data.get("draw_order",[]).find(authored_name)})
    layers.sort_custom(func(a,b):return a.z<b.z if a.z!=b.z else a.name<b.name)
    config=data;stride=clampf(float(data.get("gait",{}).get("stride_world_distance",0.09)),0.03,0.30)
    viewport=SubViewport.new();viewport.size=Vector2i(96,128);viewport.transparent_bg=true;viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(viewport)
    canvas=LayerCanvas.new();canvas.solver=solve_leg;canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;canvas.layers=layers;canvas.legs=legs
    canvas.stance=clampf(float(data.get("gait",{}).get("stance_fraction",0.60)),0.5,0.7);canvas.lift=clampf(float(data.get("gait",{}).get("swing_lift_px",2)),1,6);canvas.pelvis_drop=2.0
    viewport.add_child(canvas);canvas.pose(0,Vector2.ZERO);available=true
func draw_walk(index,direction,cycles,world_stride,step_direction):
    if not available or game.battle.units[index].id!="mara":return null
    if direction!="back_right":stop();return null
    var figure=game.figures[index];var camera=game.camera;var p=camera.unproject_position(figure.position)
    var dx=camera.unproject_position(figure.position+camera.global_basis.x*figure.pixel_size)-p
    var dy=camera.unproject_position(figure.position+Vector3.UP*figure.pixel_size)-p
    var travel=camera.unproject_position(figure.position+Vector3(step_direction.x,0,step_direction.y)*world_stride)-p
    var cycle_delta=travel/Vector2(maxf(absf(dx.x),0.001),maxf(absf(dy.y),0.001))
    canvas.pose(cycles,cycle_delta);last_error=canvas.max_error;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    return viewport.get_texture()
func stop():
    if viewport:viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
