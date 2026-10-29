extends Node2D
# Real Godot emitters. This node never calls gameplay, RNG, or result callbacks.
# Small reusable pool for Compatibility/older mobile targets; no per-frame nodes.
const TARGET_SLOTS=8
const CAST_AMOUNT=16
const TRAIL_AMOUNT=16
const BURST_AMOUNT=24
const MAX_PARTICLES=CAST_AMOUNT+TARGET_SLOTS*(TRAIL_AMOUNT+BURST_AMOUNT)
var effect
var cast:CPUParticles2D
var slots=[]
var all_emitters=[]
var entries=[]
var style='bolt'
var running=false
var burst_started=false
var texture:AtlasTexture
var shared_material:ShaderMaterial
func _ready():
    texture=AtlasTexture.new();texture.atlas=load('res://assets/battle/ranged_magic/runtime/vfx_impact.png');texture.region=Rect2(24,16,16,15)
    shared_material=ShaderMaterial.new();shared_material.shader=load('res://view/map_particle_tint.gdshader')
    cast=make_emitter('Cast',CAST_AMOUNT)
    for i in range(TARGET_SLOTS):slots.append({'trail':make_emitter('Trail'+str(i),TRAIL_AMOUNT),'burst':make_emitter('Burst'+str(i),BURST_AMOUNT)})
    stop()
func make_emitter(id,count):
    var p=CPUParticles2D.new();p.name=id;p.emitting=false;p.amount=count;p.texture=texture;p.material=shared_material
    p.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;p.local_coords=true;p.fixed_fps=30;p.fract_delta=true
    # Fixed visual seeds are completely independent of shared Lua and global rand*.
    p.lifetime=0.55
    p.use_fixed_seed=true;p.seed=7103+all_emitters.size()*97
    p.draw_order=CPUParticles2D.DRAW_ORDER_LIFETIME
    add_child(p);all_emitters.append(p)
    return p
func ramp(colors):
    var result=Gradient.new();result.colors=PackedColorArray(colors)
    result.offsets=PackedFloat32Array([0.0,0.3,1.0]);return result
func configure(p,kind):
    p.one_shot=kind=='burst';p.explosiveness=1.0 if p.one_shot else 0.0;p.randomness=0.35;p.lifetime_randomness=0.2
    p.lifetime=0.55 if kind=='burst' else (0.35 if kind=='cast' else 0.24)
    p.emission_shape=CPUParticles2D.EMISSION_SHAPE_POINTS
    p.gravity=Vector2.ZERO;p.direction=Vector2.UP;p.spread=180.0
    p.initial_velocity_min=12;p.initial_velocity_max=32
    p.scale_amount_min=0.25;p.scale_amount_max=0.5
    var size_curve=Curve.new();size_curve.add_point(Vector2(0,0.8));size_curve.add_point(Vector2(0.2,1));size_curve.add_point(Vector2(1,0.05));p.scale_amount_curve=size_curve
    if style=='ember':
        p.color_ramp=ramp([Color('fff1bb'),Color('ff8c29'),Color(0.9,0.12,0.02,0)])
        p.gravity=Vector2(0,70 if kind=='burst' else -35)
        p.spread=155 if kind=='burst' else 40
        p.initial_velocity_min=45 if kind=='burst' else 12;p.initial_velocity_max=100 if kind=='burst' else 30
        p.scale_amount_max=0.65 if kind=='burst' else 0.5
    elif style=='heal':
        p.color_ramp=ramp([Color('fff9d6'),Color('9cf2ae'),Color(0.22,0.8,0.42,0)])
        p.direction=Vector2.UP;p.spread=40 if kind=='burst' else 15;p.gravity=Vector2(0,-15)
        p.initial_velocity_min=40;p.initial_velocity_max=75
        p.scale_amount_max=0.55
    else:
        p.color_ramp=ramp([Color('f1fcff'),Color('66bfff'),Color(0.3,0.4,1.0,0)])
        p.spread=180 if kind=='burst' else 12
        p.initial_velocity_min=45 if kind=='burst' else 8;p.initial_velocity_max=90 if kind=='burst' else 24
func start(events):
    stop();style='heal' if events[0].kind=='heal' else ('ember' if events[0].get('ability')=='ember' else 'bolt')
    if App.reduced_motion:return
    running=true;entries=events.slice(0,TARGET_SLOTS).duplicate(true);burst_started=false
    configure(cast,'cast')
    for i in range(entries.size()):configure(slots[i].trail,'trail');configure(slots[i].burst,'burst')
    update_plane();place(cast,effect.screen(events[0].actor,0.4),6);activate(cast)
func update_plane():
    # Static simulation plane: moving emission points leave a real particle trail.
    # Translating/scaling the plane keeps already-emitted particles on the map
    # during orthographic focus, shake and viewport resize.
    var camera=effect.game.camera
    position=camera.unproject_position(Vector3.ZERO)
    var pixels=position.distance_to(camera.unproject_position(camera.global_basis.x))
    scale=Vector2.ONE*maxf(0.01,pixels/64.0)
func in_view(point):
    var area=get_viewport_rect()
    if effect.game.scene_view and effect.game.scene_view.active:area=effect.game.scene_view.art_rect
    return area.grow(48).has_point(point)
func place(p,point,radius=2.0):
    var local=to_local(point)
    p.emission_points=PackedVector2Array([local+Vector2(-radius,0),local,local+Vector2(radius,0)])
    p.visible=in_view(point)
    return p.visible
func activate(p):
    if not p.visible:return
    p.set_meta('launched',true);p.restart(true);p.emitting=true
func advance(time):
    if not running:return
    if App.reduced_motion:stop();return
    update_plane()
    if time<0.30:
        place(cast,effect.screen(effect.items[0].actor,0.4),6)
        if not cast.visible:cast.emitting=false
        return
    cast.emitting=false
    if time<effect.IMPACT_TIME:
        var t=clampf((time-0.30)/(effect.IMPACT_TIME-0.30),0,1)
        for i in range(entries.size()):
            var e=entries[i];var p=slots[i].trail
            var source=effect.screen(e.actor,0.55);var target=effect.screen(e.target,0.5)
            var at=effect.screen(e.target,0.12) if style=='heal' else source.lerp(target,t)
            if style!='heal':p.direction=(source-target).normalized()
            if place(p,at,14.0 if style=='heal' else 2.0):
                if not p.get_meta('launched',false):activate(p)
            else:p.emitting=false
        return
    for i in range(entries.size()):slots[i].trail.emitting=false
    if not burst_started:
        burst_started=true
        for i in range(entries.size()):
            var p=slots[i].burst
            place(p,effect.screen(entries[i].target,0.3 if style=='heal' else 0.5),18.0 if style=='heal' else 3.0);activate(p)
    else:
        # Cull completed/offscreen emitters; never spawn deferred impacts on return.
        for i in range(entries.size()):
            if not in_view(effect.screen(entries[i].target,0.5)):slots[i].burst.hide();slots[i].burst.emitting=false
func stop():
    running=false;entries.clear();burst_started=false
    for p in all_emitters:
        p.hide();p.emitting=false;p.restart(true);p.emitting=false;p.set_process_internal(false);p.set_meta('launched',false)
func diagnostics():
    return {'engine_class':'CPUParticles2D','pool_nodes':all_emitters.size(),'capacity':MAX_PARTICLES,'target_slots':TARGET_SLOTS,
        'visible_nodes':all_emitters.filter(func(p):return p.visible).size(),
        'emitting_nodes':all_emitters.filter(func(p):return p.emitting).size(),'style':style,'running':running}
func _exit_tree():stop()
