extends Node
# Reversible presentation adapter for explicitly matched authored maps.
const BACKGROUND="res://assets/backgrounds/amber_bridge/background.png"
const FOREGROUND="res://assets/backgrounds/amber_bridge/foreground.png"
var game
var active=false
var hidden=[]
var backdrop:MeshInstance3D
var foreground:MeshInstance3D
var shadows=[]
var painted_lights=[]
var original_lights=[]
var saved_size=11.8
var authored_size=11.8
var tactical_marks=[]
var saved_aspect=Camera3D.KEEP_HEIGHT
var art_rect=Rect2()
var original_character_scale=1.0
var compatibility_message=""
var authored={}
var saved_camera_position=Vector3.ZERO
var camera_origin=Vector3.ZERO
var pan=Vector2.ZERO
var pan_limit=Vector2.ZERO
var focus_active=false
var focus_point=Vector3.ZERO
var focus_start=Vector2.ZERO
var focus_elapsed=0.0
const FOCUS_SECONDS=0.28
func cancel_focus():focus_active=false
func focus_actor(point):
    if not active or not App.mobile_presentation:return
    fit();focus_point=point;focus_start=pan;focus_elapsed=0.0
    focus_active=not pan.is_equal_approx(focus_pan())
    if App.reduced_motion:pan=focus_pan();focus_active=false;fit()
func focus_pan():
    var offset=focus_point-camera_origin
    return Vector2(offset.dot(game.camera.global_basis.x),offset.dot(game.camera.global_basis.y)).clamp(-pan_limit,pan_limit)
func compatible():
    return not preload("res://view/authored_scene.gd").profile(game.battle.content).is_empty()
func available():
    var spec=preload("res://view/authored_scene.gd").profile(game.battle.content)
    if spec.is_empty() or not ResourceLoader.exists(spec.map):return false
    var texture=load(spec.map)
    return texture is Texture2D and texture.get_size()==spec.canvas
func _ready():
    process_priority=100
    saved_size=game.camera.size;saved_aspect=game.camera.keep_aspect;saved_camera_position=game.camera.position
func plate(texture,depth,transparent=false):
    var mesh=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(authored_size*(float(texture.get_width())/texture.get_height() if texture.get_size()==Vector2(1586,992) else 1.6),authored_size);mesh.mesh=quad
    mesh.transform=game.camera.transform;mesh.position-=game.camera.global_basis.z*depth
    var shader=Shader.new()
    shader.code="shader_type spatial; render_mode unshaded, fog_disabled, cull_disabled; uniform sampler2D art: source_color, filter_nearest; void fragment(){ vec4 c=texture(art,UV); ALBEDO=c.rgb;"+("ALPHA=c.a;" if transparent else "")+"}"
    var mat=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("art",texture);mesh.material_override=mat
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;game.add_child(mesh);return mesh
func set_fixed(enabled,fixture_texture:Texture2D=null):
    if enabled==active:return true
    cancel_focus()
    if enabled and not compatible():
        var authored=preload("res://logic/content.gd").reference_content()
        if game.battle.content.id==authored.id and game.battle.content.revision<authored.revision:
            compatibility_message="旧版地图 · 3D兼容视图"
        return false
    if enabled and fixture_texture==null and not available():return false
    compatibility_message=""
    if enabled:
        authored=preload("res://view/authored_scene.gd").profile(game.battle.content)
        game.camera.position=saved_camera_position+game.camera.global_basis.x*authored.camera_offset.x+game.camera.global_basis.y*authored.camera_offset.y
        authored_size=saved_size
        game.scene_render_scale=1.0
        if authored.has("projection_contract"):
            var c=authored.projection_contract
            authored_size=800.0*absf(game.camera.global_basis.x.x)/float(c.basis_x[0])
            var ppu=800.0/authored_size
            var zero=Vector2(640.0-game.camera.position.dot(game.camera.global_basis.x)*ppu,400.0+game.camera.position.dot(game.camera.global_basis.y)*ppu)
            game.camera.position+=game.camera.global_basis.x*((zero.x-float(c.origin[0]))/ppu)+game.camera.global_basis.y*((float(c.origin[1])-zero.y)/ppu)
            game.scene_render_scale=authored_size/saved_size
        camera_origin=game.camera.position;pan=Vector2.ZERO
        var keep=[game.ground_overlay,game.camera,game.route_mesh,game.route_arrows,game.selection_ring,game.preview_ghost]
        keep.append_array(game.figures);keep.append_array(game.badges)
        for tile in game.tiles.values():keep.append(tile.overlay)
        for node in game.get_children():
            if node in keep:continue
            if node is GeometryInstance3D or node.get_class()=="Node3D":
                hidden.append([node,node.visible]);node.hide()
        original_character_scale=game.character_scale
        var settings_path=authored.root+"presentation.json"
        var scale_factor=1.25 if game.battle.content.id in ["white_elm_watchhouse","mill_receipts","homeward_02","homeward_03"] else 1.0
        if FileAccess.file_exists(settings_path):scale_factor=float(JSON.parse_string(FileAccess.get_file_as_string(settings_path)).get("character_scale",1.0))
        game.set_character_scale(scale_factor)
        backdrop=plate(fixture_texture if fixture_texture!=null else load(authored.map),50)
        if fixture_texture==null and ResourceLoader.exists(authored.root+"foreground.png"):foreground=plate(load(authored.root+"foreground.png"),2,true)
        var shader=Shader.new();shader.code="shader_type spatial; render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never; void fragment(){float d=length((UV-vec2(0.5))*2.0);ALBEDO=vec3(0.06,0.08,0.07);ALPHA=(1.0-smoothstep(0.15,1.0,d))*0.32;}"
        var material=ShaderMaterial.new();material.shader=shader
        for unit in game.battle.units:
            var shadow=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(0.56,0.38)*game.character_scale*game.map_render_factor(unit.id);shadow.mesh=plane;shadow.material_override=material;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;game.add_child(shadow);shadows.append(shadow)
        active=true;fit();setup_lights();sync_shadows();setup_tactical_marks()
    else:
        for entry in hidden:
            if is_instance_valid(entry[0]):entry[0].visible=entry[1]
        hidden.clear()
        for entry in original_lights:
            if is_instance_valid(entry[0]):entry[0].visible=entry[1]
        original_lights.clear()
        for light in painted_lights:light.queue_free()
        painted_lights.clear()
        for node in [backdrop,foreground]+shadows+tactical_marks:
            if is_instance_valid(node):node.queue_free()
        backdrop=null;foreground=null;shadows.clear();tactical_marks.clear();active=false
        game.scene_render_scale=1.0
        game.set_character_scale(original_character_scale)
        game.camera.size=saved_size;game.camera.keep_aspect=saved_aspect;game.camera.position=saved_camera_position
    game.clear_move_preview()
    return true
func fit():
    var view=game.get_viewport().get_visible_rect().size
    if App.mobile_presentation:
        # Cover the viewport uniformly. Panning reveals the cropped dimension.
        var aspect=view.x/maxf(1.0,view.y)
        var map_aspect=authored.canvas.x/authored.canvas.y
        var height=minf(authored_size,authored_size*map_aspect/aspect)
        game.camera.keep_aspect=Camera3D.KEEP_HEIGHT;game.camera.size=height
        pan_limit=Vector2(maxf(0.0,(authored_size*map_aspect-height*aspect)*0.5),maxf(0.0,(authored_size-height)*0.5))
        pan=pan.clamp(-pan_limit,pan_limit)
        game.camera.position=camera_origin+game.camera.global_basis.x*pan.x+game.camera.global_basis.y*pan.y
        art_rect=Rect2(Vector2.ZERO,view)
        return
    var scale_factor=minf(view.x/1280.0,view.y/800.0)
    var extent=Vector2(1280,800)*scale_factor;art_rect=Rect2((view-extent)*0.5,extent)
    if view.x/view.y>=1.6:game.camera.keep_aspect=Camera3D.KEEP_HEIGHT;game.camera.size=authored_size
    else:game.camera.keep_aspect=Camera3D.KEEP_WIDTH;game.camera.size=authored_size*1.6
func pan_by(screen_delta):
    if not active or not App.mobile_presentation:return
    cancel_focus()
    var units=game.camera.size/maxf(1.0,game.get_viewport().get_visible_rect().size.y)
    pan+=Vector2(-screen_delta.x,screen_delta.y)*units
    fit()
func accepts_point(point):return not active or art_rect.has_point(point)
func sync_shadows():
    for i in range(shadows.size()):
        var p=game.figures[i].position
        var footprint=Vector2(0.56,0.38)*game.character_scale*game.map_render_factor(game.battle.units[i].id)
        if not shadows[i].mesh.size.is_equal_approx(footprint):shadows[i].mesh.size=footprint
        shadows[i].position=Vector3(p.x,0.008,p.z);shadows[i].visible=game.battle.units[i].hp>0
func _process(delta):
    if not active:return
    fit()
    if focus_active:
        focus_elapsed=minf(FOCUS_SECONDS,focus_elapsed+delta)
        var t=focus_elapsed/FOCUS_SECONDS;t=t*t*(3.0-2.0*t)
        pan=focus_start.clamp(-pan_limit,pan_limit).lerp(focus_pan(),t)
        if focus_elapsed>=FOCUS_SECONDS:focus_active=false
        fit()
    sync_shadows()

func setup_lights():
    for node in game.get_children():
        if node is OmniLight3D:original_lights.append([node,node.visible]);node.hide()
    var path=authored.root+"lights.json"
    var data={"lights":[]}
    if FileAccess.file_exists(path):data=JSON.parse_string(FileAccess.get_file_as_string(path))
    elif authored.has("projection_contract"):
        # Measured on original 1586x992 pixels; local lights affect actors only.
        for anchor in [["office",1156,348],["north",1076,231],["west",172,391],["south",179,630]]:
            data.lights.append({"id":anchor[0],"pixel":[anchor[1]*1280.0/1586.0,anchor[2]*800.0/992.0],"height":1.4,"color":"efbe7b","energy":0.8,"range":2.5,"attenuation":1.5})
    for spec in data.get("lights",[]):
        var point=art_rect.position+Vector2(spec.pixel[0],spec.pixel[1])*art_rect.size.x/1280.0
        if authored.has("projection_contract"):
            var ppu=800.0/authored_size
            var world=camera_origin+game.camera.global_basis.x*((float(spec.pixel[0])-640.0)/ppu)+game.camera.global_basis.y*((400.0-float(spec.pixel[1]))/ppu)
            point=game.camera.unproject_position(world)
        var origin=game.camera.project_ray_origin(point);var ray=game.camera.project_ray_normal(point)
        var light=OmniLight3D.new();light.position=origin+ray*((float(spec.height)-origin.y)/ray.y)
        light.light_color=Color(spec.color);light.light_energy=clampf(float(spec.energy),0,2)
        light.omni_range=clampf(float(spec.range),0.1,5);light.omni_attenuation=clampf(float(spec.attenuation),0.5,3)
        light.light_cull_mask=2;light.shadow_enabled=false
        light.set_meta("anchor_pixel",Vector2(spec.pixel[0],spec.pixel[1]));light.set_meta("anchor_id",spec.id)
        game.add_child(light);painted_lights.append(light)

func setup_tactical_marks():
    if not authored.has("projection_contract"):return
    var mesh=ImmediateMesh.new()
    var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("b4a778");mat.no_depth_test=false
    mesh.surface_begin(Mesh.PRIMITIVE_LINES,mat)
    # Outline only playable/X or off-map interfaces. Grass-painted X cells
    # remain visibly outside the playable area; water already has its own bank.
    var rows=game.battle.content.terrain
    for y in range(game.battle.size.y):
        for x in range(game.battle.size.x):
            if rows[y][x] in ["W","X"]:continue
            var center=Vector3(x,0.025,y)
            for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
                var n=Vector2i(x,y)+delta
                if n.x>=0 and n.x<game.battle.size.x and n.y>=0 and n.y<game.battle.size.y and rows[n.y][n.x]!="X":continue
                var edge_center=center+Vector3(delta.x,0,delta.y)*0.5
                var tangent=Vector3(-delta.y,0,delta.x)*0.5
                for i in range(4):
                    mesh.surface_add_vertex((edge_center-tangent).lerp(edge_center+tangent,i/4.0))
                    mesh.surface_add_vertex((edge_center-tangent).lerp(edge_center+tangent,(i+0.6)/4.0))
    mesh.surface_end()
    var boundary=MeshInstance3D.new();boundary.mesh=mesh;boundary.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;game.add_child(boundary);tactical_marks.append(boundary)
    var goal=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(0.85,0.85);goal.mesh=plane
    var gold=StandardMaterial3D.new();gold.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;gold.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;gold.albedo_texture=load("res://assets/ui/bottom_dock_reference/ground/target_cell_border_gold.png");gold.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
    goal.material_override=gold;goal.position=Vector3(8,0.026,1);goal.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;game.add_child(goal);tactical_marks.append(goal)
