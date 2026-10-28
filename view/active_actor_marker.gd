extends Node
# Presentation follows the event being shown, never changes the selected rule actor.
var game
var arrow:TextureRect
var foot:MeshInstance3D
var material:StandardMaterial3D
var clock=0.0
var actor_index=-1
var ally_arrow=preload("res://assets/ui/party_eye_v2/actor_arrow_ally.png")
var enemy_arrow=preload("res://assets/ui/party_eye_v2/actor_arrow_enemy.png")
func _ready():
    process_priority=130
    arrow=TextureRect.new();arrow.name="ActiveActorArrow";arrow.texture=ally_arrow
    arrow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;arrow.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE
    arrow.size=Vector2(36,25.2);game.hud.root.add_child(arrow)
    foot=MeshInstance3D.new();foot.name="ActiveActorFoot";var plane=PlaneMesh.new();plane.size=Vector2(1.4,1.4);foot.mesh=plane
    material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_texture=load("res://assets/ui/party_eye_v2/ground_diamond.png");material.cull_mode=BaseMaterial3D.CULL_DISABLED
    foot.rotation.y=PI/4
    foot.material_override=material;foot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;game.add_child(foot)
func active_index():
    var actor=""
    if game.event_sequence and not game.event_sequence.current.is_empty():actor=game.event_sequence.current.get("actor","")
    elif game.motion and not game.motion.motions.is_empty():actor=game.motion.motions.keys()[0]
    if not actor.is_empty():
        for i in range(game.battle.units.size()):
            if game.battle.units[i].id==actor:return i
    return game.selected
func _process(delta):
    if not App.reduced_motion:clock+=minf(delta,.1)
    actor_index=active_index()
    var valid=actor_index>=0 and actor_index<game.figures.size()
    var obscured=is_instance_valid(game.hud.modal) or game.hud.story_panel.visible or (game.cutin and game.cutin.active)
    if valid:valid=game.figures[actor_index].visible
    arrow.visible=valid and not obscured;foot.visible=valid and not obscured
    game.selection_ring.visible=false
    if not valid:return
    var ally=game.battle.units[actor_index].ally
    var color=Color("f5dda1") if ally else Color("ef7963")
    var pulse=0.0 if App.reduced_motion else sin(clock*3.0)
    material.albedo_color=Color(color.r,color.g,color.b,.88+.08*pulse)
    var pos=game.figures[actor_index].position;foot.position=Vector3(pos.x,.045,pos.z)
    foot.scale=Vector3.ONE*(1.0+.035*pulse)
    var center=game.camera.unproject_position(game.badges[actor_index].position)
    arrow.position=center-game.hud.root.global_position-Vector2(18,46+(0.0 if App.reduced_motion else pulse*2.0))
    arrow.texture=ally_arrow if ally else enemy_arrow
    arrow.modulate=Color.WHITE
    # A marker is decorative, never clamped onto unrelated HUD controls.
    if not Rect2(Vector2.ZERO,game.hud.root.size).encloses(Rect2(arrow.position,arrow.size)) or game.hud.pointer_blocks_map(arrow.global_position+arrow.size*.5):arrow.hide()
func _exit_tree():
    if is_instance_valid(arrow):arrow.queue_free()
    if is_instance_valid(foot):foot.queue_free()
