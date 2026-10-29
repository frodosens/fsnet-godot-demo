extends Node2D
# Core silhouettes are actual SpriteFrames displayed by AnimatedSprite2D nodes.
# Frame selection and phase transitions are driven by the owner's AnimationPlayer.
const TARGET_SLOTS=8
const ASSET_ROOT='res://assets/effects/map_spells/'
const STAGES=['cast','travel','impact']
var effect
var caster:AnimatedSprite2D
var targets=[]
var entries=[]
var frame_sets={}
var authored={}
var running=false
var style='focus_bolt'
var phase=0:
    set(value):
        phase=value
        if is_instance_valid(caster):update_frames()
var frame_progress=0.0:
    set(value):
        frame_progress=value
        if is_instance_valid(caster):update_frames()
var travel_progress=0.0
func _ready():
    for id in ['ember','focus_bolt','heal']:frame_sets[id]=load_frames(id)
    caster=make_sprite('CastCore')
    for i in range(TARGET_SLOTS):targets.append(make_sprite('TargetCore'+str(i)))
    stop()
func make_sprite(id):
    var sprite=AnimatedSprite2D.new();sprite.name=id;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(sprite);return sprite
func load_frames(id):
    var frames=SpriteFrames.new();frames.remove_animation('default')
    var sheet_path=ASSET_ROOT+id+'.png'
    var sheet=load(sheet_path) if ResourceLoader.exists(sheet_path) else null
    var genuine=sheet!=null and sheet.get_size()==Vector2(384,384)
    authored[id]=genuine
    var fallback=[['gather','charge'],['bolt'],['impact','dissipate']]
    for stage in range(3):
        frames.add_animation(STAGES[stage]);frames.set_animation_loop(STAGES[stage],false)
        var count=[4,4,8][stage] if genuine else fallback[stage].size()
        frames.set_animation_speed(STAGES[stage],count/[0.30,0.32,0.73][stage])
        for i in range(count):
            var atlas=AtlasTexture.new()
            if genuine:
                atlas.atlas=sheet;var index=[0,4,8][stage]+i
                atlas.region=Rect2((index%4)*96,(index/4)*96,96,96)
            else:
                atlas.atlas=load('res://assets/battle/ranged_magic/runtime/vfx_'+fallback[stage][i]+'.png');atlas.region=Rect2(16,12,32,24)
            frames.add_frame(STAGES[stage],atlas)
    return frames
func start(events):
    stop();running=true;entries=events.slice(0,TARGET_SLOTS).duplicate(true)
    style='heal' if events[0].kind=='heal' else events[0].get('ability','focus_bolt')
    caster.sprite_frames=frame_sets[style]
    for sprite in targets:sprite.sprite_frames=frame_sets[style]
    phase=0;frame_progress=0;travel_progress=0
    update_projection()
func update_frames():
    if not running:return
    var stage=STAGES[clampi(phase,0,2)]
    var frames=frame_sets[style]
    var index=0 if App.reduced_motion else mini(frames.get_frame_count(stage)-1,int(clampf(frame_progress,0,1)*frames.get_frame_count(stage)))
    for sprite in [caster]+targets:
        sprite.animation=stage;sprite.frame=index
func position_sprite(sprite,point,span):
    sprite.position=point
    # Measured source alignment: focus charge/travel mass is ~8px low.
    sprite.offset=Vector2(0,-8) if authored.get(style,false) and style=='focus_bolt' and phase<2 else Vector2.ZERO
    if authored.get(style,false) and style=='heal':span*=1.3
    var texture=sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
    var camera=effect.game.camera
    var pixels=camera.unproject_position(camera.global_basis.x).distance_to(camera.unproject_position(Vector3.ZERO))
    sprite.scale=Vector2.ONE*pixels*span/maxf(1,texture.get_width())
    sprite.visible=get_viewport_rect().grow(64).has_point(point)
func update_projection():
    if not running or entries.is_empty():return
    update_frames();caster.hide()
    for sprite in targets:sprite.hide()
    if phase==0:
        caster.rotation=0;position_sprite(caster,effect.screen(entries[0].actor,.55),.8)
    else:
        for i in range(entries.size()):
            var e=entries[i];var sprite=targets[i];var source=effect.screen(e.actor,.55);var target=effect.screen(e.target,.5)
            var point=target;var span=1.2
            sprite.rotation=0
            if phase==1:
                span=.65
                point=effect.screen(e.target,.15+.4*travel_progress) if style=='heal' else source.lerp(target,travel_progress)
                if style!='heal':sprite.rotation=(target-source).angle()
                if App.reduced_motion:continue
            position_sprite(sprite,point,span)
            sprite.modulate.a=1.0 if phase<2 else clampf((effect.DURATION-effect.elapsed)/.25,0,1)
func stop():
    running=false;entries.clear()
    for sprite in [caster]+targets:
        if is_instance_valid(sprite):
            sprite.stop();sprite.hide();sprite.modulate=Color.WHITE;sprite.rotation=0;sprite.scale=Vector2.ONE;sprite.position=Vector2.ZERO;sprite.offset=Vector2.ZERO
            if sprite.sprite_frames and sprite.sprite_frames.has_animation('cast'):sprite.animation='cast';sprite.frame=0
func diagnostics():
    var counts={}
    for id in frame_sets:
        counts[id]={'authored_sheet':authored[id],'cast':frame_sets[id].get_frame_count('cast'),'travel':frame_sets[id].get_frame_count('travel'),'impact':frame_sets[id].get_frame_count('impact')}
    return {'engine_class':'AnimatedSprite2D','core_nodes':1+targets.size(),'frames':counts}
