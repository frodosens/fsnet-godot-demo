extends Node2D
# Presentation consumes settled events only. No rule calls, RNG, or resource writes.
const UI=preload("res://ui/style.gd")
const IMPACT_TIME=0.62
const DURATION=1.35
var game
var active=false
var elapsed=0.0
var impacted=false
var items=[]
var points={}
var labels=[]
var original_colors={}
var saved_pan=Vector2.ZERO
var focus_pan=Vector2.ZERO
var owns_camera=false
var impact_count=0
var particles
var core
var timeline:AnimationPlayer
static func accepts(event,content):
    if event.get('kind')=='heal':return true
    if event.get('kind')!='attack' or event.get('ability') not in ['ember','focus_bolt']:return false
    var profile=""
    for unit in content.get("units",[]):
        if unit.id==event.get("actor"):profile=PresentationProfiles.resolve(unit);break
    if PresentationProfiles.combat(profile).get("projectile")!="magic":return false
    for ability in content.get('abilities',[]):
        if ability.id==event.ability:return ability.get('damage_type')=='magic'
    return false
func _ready():
    process_priority=105
    particles=preload('res://view/map_spell_particles.gd').new();particles.name='MapSpellParticles';particles.effect=self;add_child(particles)
    core=preload('res://view/map_spell_core.gd').new();core.name='Core';core.effect=self;add_child(core)
    build_timeline()
func build_timeline():
    timeline=AnimationPlayer.new();timeline.name='SpellTimeline';timeline.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;add_child(timeline)
    var animation=Animation.new();animation.length=DURATION
    value_track(animation,NodePath('.:elapsed'),[[0.0,0.0],[DURATION,DURATION]])
    value_track(animation,NodePath('Core:phase'),[[0.0,0],[0.30,1],[IMPACT_TIME,2]],true)
    value_track(animation,NodePath('Core:frame_progress'),[[0.0,0.0],[0.29999,0.9999],[0.30,0.0],[IMPACT_TIME-0.00001,0.9999],[IMPACT_TIME,0.0],[DURATION,0.9999]])
    value_track(animation,NodePath('Core:travel_progress'),[[0.0,0.0],[0.30,0.0],[IMPACT_TIME,1.0],[DURATION,1.0]])
    var library=AnimationLibrary.new();library.add_animation('spell',animation);timeline.add_animation_library('',library)
func value_track(animation,path,keys,discrete=false):
    var index=animation.add_track(Animation.TYPE_VALUE);animation.track_set_path(index,path)
    animation.value_track_set_update_mode(index,Animation.UPDATE_DISCRETE if discrete else Animation.UPDATE_CONTINUOUS)
    for key in keys:animation.track_insert_key(index,key[0],key[1])
func start(events,positions):
    finish();items=events.duplicate(true);elapsed=0;impacted=false;active=true
    for id in positions:
        var p=positions[id];points[id]=Vector3(p.x,0.06,p.y)
    var scene=game.scene_view
    if scene and scene.active and App.mobile_presentation and not App.reduced_motion:
        scene.cancel_focus();scene.fit();saved_pan=scene.pan
        var center=Vector3.ZERO
        for e in items:center+=points[e.target]
        center/=items.size()
        var offset=center-scene.camera_origin
        focus_pan=Vector2(offset.dot(game.camera.global_basis.x),offset.dot(game.camera.global_basis.y)).clamp(-scene.pan_limit,scene.pan_limit)
        owns_camera=true
    core.start(items);particles.start(items)
    timeline.play('spell');timeline.advance(0)
    game.cutin.play_sound('magic')
    queue_redraw()
func _process(delta):
    if not active:return
    timeline.advance(maxf(0,delta))
    if owns_camera and App.reduced_motion:
        game.scene_view.pan=saved_pan;game.scene_view.fit();owns_camera=false
    if owns_camera:
        var scene=game.scene_view
        var weight=smoothstep(0.0,0.28,elapsed)*(1.0-smoothstep(1.05,DURATION,elapsed))
        var shake=Vector2.ZERO
        if not App.reduced_motion and elapsed>=IMPACT_TIME and elapsed<IMPACT_TIME+0.16:
            shake.x=sin((elapsed-IMPACT_TIME)*90.0)*0.025*(1.0-(elapsed-IMPACT_TIME)/0.16)
        scene.pan=(saved_pan.lerp(focus_pan,weight)+shake).clamp(-scene.pan_limit,scene.pan_limit);scene.fit()
    core.update_projection();particles.advance(elapsed)
    if not impacted and elapsed>=IMPACT_TIME:
        impacted=true;impact_count+=items.size()
        game.event_sequence.map_impact()
        game.cutin.play_sound('impact' if items[0].kind=='attack' else 'magic')
        for e in items:
            var label=UI.label(('+'+str(e.amount)) if e.kind=='heal' else ('暴击 ' if e.get('is_critical',false) else '')+str(e.damage),28,Color('b6d5a2') if e.kind=='heal' else Color('ffe2b0'))
            label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_color_override('font_outline_color',Color('182421'));label.add_theme_constant_override('outline_size',4);add_child(label)
            labels.append({'node':label,'target':e.target})
            for i in range(game.battle.units.size()):
                if game.battle.units[i].id==e.target:
                    original_colors[i]=game.figures[i].modulate
                    if not App.reduced_motion:game.figures[i].modulate=Color(1.8,1.6,1.2)
    if impacted:
        if elapsed>=IMPACT_TIME+0.12:restore_colors()
        for entry in labels:
            entry.node.position=screen(entry.target,0.95)+Vector2(-20,-20 if App.reduced_motion else -20-25*(elapsed-IMPACT_TIME))
            entry.node.modulate.a=clampf((DURATION-elapsed)/0.25,0,1)
    if elapsed>=DURATION:finish()
    queue_redraw()
func screen(id,height=0.0):return game.camera.unproject_position(points.get(id,Vector3.ZERO)+Vector3.UP*height)
func rune(id,color):
    var ring=PackedVector2Array()
    for n in range(33):
        var angle=n*TAU/32.0
        ring.append(game.camera.unproject_position(points[id]+Vector3(cos(angle)*0.42,0,sin(angle)*0.42)))
    draw_polyline(ring,color,2.0,true)
    for axis in [Vector3(0.28,0,0),Vector3(0,0,0.28)]:
        draw_line(game.camera.unproject_position(points[id]-axis),game.camera.unproject_position(points[id]+axis),color,2.0,true)
func _draw():
    if not active or items.is_empty():return
    var healing=items[0].kind=='heal'
    var tint=Color('b6e0b4') if healing else (Color('ffac55') if items[0].get('ability')=='ember' else Color('b8e6ff'))
    var actor=items[0].actor
    if elapsed<IMPACT_TIME:rune(actor,tint)
    else:
        tint.a=clampf((DURATION-elapsed)/0.35,0,1)
        for e in items:rune(e.target,tint)
func restore_colors():
    for i in original_colors:
        if i<game.figures.size():game.figures[i].modulate=original_colors[i]
    original_colors.clear()
func finish():
    if timeline:timeline.stop()
    if core:core.stop()
    if particles:particles.stop()
    restore_colors()
    if owns_camera and game.scene_view:
        game.scene_view.cancel_focus();game.scene_view.pan=saved_pan;game.scene_view.fit()
    owns_camera=false;active=false
    for entry in labels:entry.node.queue_free()
    labels.clear();points.clear();items.clear();queue_redraw()
