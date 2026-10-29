extends Node2D
# Presentation consumes settled events only. No rule calls, RNG, or resource writes.
const UI=preload('res://ui/style.gd')
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
var textures={}
var saved_pan=Vector2.ZERO
var focus_pan=Vector2.ZERO
var owns_camera=false
var impact_count=0
static func accepts(event,content):
    if event.get('kind')=='heal':return true
    if event.get('kind')!='attack' or event.get('actor')!='neri' or event.get('ability') not in ['ember','focus_bolt']:return false
    for ability in content.get('abilities',[]):
        if ability.id==event.ability:return ability.get('damage_type')=='magic'
    return false
func _ready():
    process_priority=105
    for state in ['gather','charge','bolt','impact','dissipate']:
        textures[state]=load('res://assets/battle/ranged_magic/runtime/vfx_'+state+'.png')
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
    game.cutin.play_sound('magic')
    queue_redraw()
func _process(delta):
    if not active:return
    elapsed+=maxf(0,delta)
    if owns_camera and App.reduced_motion:
        game.scene_view.pan=saved_pan;game.scene_view.fit();owns_camera=false
    if owns_camera:
        var scene=game.scene_view
        var weight=smoothstep(0.0,0.28,elapsed)*(1.0-smoothstep(1.05,DURATION,elapsed))
        var shake=Vector2.ZERO
        if not App.reduced_motion and elapsed>=IMPACT_TIME and elapsed<IMPACT_TIME+0.16:
            shake.x=sin((elapsed-IMPACT_TIME)*90.0)*0.025*(1.0-(elapsed-IMPACT_TIME)/0.16)
        scene.pan=(saved_pan.lerp(focus_pan,weight)+shake).clamp(-scene.pan_limit,scene.pan_limit);scene.fit()
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
func stamp(state,point,size,tint):
    # Authored effects occupy the central half of their padded 64x48 canvas.
    draw_texture_rect_region(textures[state],Rect2(point-size*0.5,size),Rect2(16,12,32,24),tint)
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
    var tint=Color('b6e0b4') if healing else Color('b8e6ff')
    var actor=items[0].actor
    var scale_factor=clampf(get_viewport_rect().size.y/800.0,0.6,2.0)
    if elapsed<IMPACT_TIME:
        rune(actor,tint)
        stamp('gather' if elapsed<0.25 else 'charge',screen(actor,0.55),Vector2(64,48)*scale_factor,tint)
        if elapsed>=0.30 and not App.reduced_motion:
            var progress=clampf((elapsed-0.30)/(IMPACT_TIME-0.30),0,1)
            for e in items:stamp('bolt',screen(actor,0.55).lerp(screen(e.target,0.5),progress),Vector2(48,36)*scale_factor,tint)
    else:
        tint.a=clampf((DURATION-elapsed)/0.35,0,1)
        for e in items:
            rune(e.target,tint)
            stamp('impact' if elapsed<IMPACT_TIME+0.22 else 'dissipate',screen(e.target,0.45),Vector2(90,68)*scale_factor,tint)
func restore_colors():
    for i in original_colors:
        if i<game.figures.size():game.figures[i].modulate=original_colors[i]
    original_colors.clear()
func finish():
    restore_colors()
    if owns_camera and game.scene_view:
        game.scene_view.cancel_focus();game.scene_view.pan=saved_pan;game.scene_view.fit()
    owns_camera=false;active=false
    for entry in labels:entry.node.queue_free()
    labels.clear();points.clear();items.clear();queue_redraw()
