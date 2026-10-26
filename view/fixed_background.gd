extends Node
# Reversible presentation adapter for the single authored reference map.
const BACKGROUND="res://assets/backgrounds/amber_bridge/background.png"
const FOREGROUND="res://assets/backgrounds/amber_bridge/foreground.png"
var game
var active=false
var hidden=[]
var backdrop:MeshInstance3D
var foreground:MeshInstance3D
var shadows=[]
var saved_size=11.8
var saved_aspect=Camera3D.KEEP_HEIGHT
var art_rect=Rect2()
func compatible():
    var authored=preload("res://logic/content.gd").reference_content()
    var current=game.battle.content
    return current.id==authored.id and current.width==authored.width and current.height==authored.height and current.terrain==authored.terrain
func available():
    if not compatible() or not ResourceLoader.exists(BACKGROUND):return false
    var texture=load(BACKGROUND)
    return texture is Texture2D and texture.get_size()==Vector2(1280,800)
func _ready():
    process_priority=100
    saved_size=game.camera.size;saved_aspect=game.camera.keep_aspect
func plate(texture,depth,transparent=false):
    var mesh=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(saved_size*1.6,saved_size);mesh.mesh=quad
    mesh.transform=game.camera.transform;mesh.position-=game.camera.global_basis.z*depth
    var shader=Shader.new()
    shader.code="shader_type spatial; render_mode unshaded, fog_disabled, cull_disabled; uniform sampler2D art: source_color, filter_nearest; void fragment(){ vec4 c=texture(art,UV); ALBEDO=c.rgb;"+("ALPHA=c.a;" if transparent else "")+"}"
    var mat=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("art",texture);mesh.material_override=mat
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;game.add_child(mesh);return mesh
func set_fixed(enabled,fixture_texture:Texture2D=null):
    if enabled==active:return true
    if enabled and (not compatible() or (fixture_texture==null and not available())):return false
    if enabled:
        var keep=[game.camera,game.route_mesh,game.route_arrows,game.selection_ring,game.preview_ghost]
        keep.append_array(game.figures);keep.append_array(game.badges)
        for tile in game.tiles.values():keep.append(tile.overlay)
        for node in game.get_children():
            if node in keep:continue
            if node is GeometryInstance3D or node.get_class()=="Node3D":
                hidden.append([node,node.visible]);node.hide()
        backdrop=plate(fixture_texture if fixture_texture!=null else load(BACKGROUND),50)
        if fixture_texture==null and ResourceLoader.exists(FOREGROUND):foreground=plate(load(FOREGROUND),2,true)
        var shader=Shader.new();shader.code="shader_type spatial; render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never; void fragment(){float d=length((UV-vec2(0.5))*2.0);ALBEDO=vec3(0.06,0.08,0.07);ALPHA=(1.0-smoothstep(0.15,1.0,d))*0.32;}"
        var material=ShaderMaterial.new();material.shader=shader
        for unit in game.battle.units:
            var shadow=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(0.56,0.38);shadow.mesh=plane;shadow.material_override=material;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;game.add_child(shadow);shadows.append(shadow)
        active=true;fit();sync_shadows()
    else:
        for entry in hidden:
            if is_instance_valid(entry[0]):entry[0].visible=entry[1]
        hidden.clear()
        for node in [backdrop,foreground]+shadows:
            if is_instance_valid(node):node.queue_free()
        backdrop=null;foreground=null;shadows.clear();active=false
        game.camera.size=saved_size;game.camera.keep_aspect=saved_aspect
    game.clear_move_preview()
    return true
func fit():
    var view=game.get_viewport().get_visible_rect().size
    var scale_factor=minf(view.x/1280.0,view.y/800.0)
    var extent=Vector2(1280,800)*scale_factor;art_rect=Rect2((view-extent)*0.5,extent)
    if view.x/view.y>=1.6:game.camera.keep_aspect=Camera3D.KEEP_HEIGHT;game.camera.size=saved_size
    else:game.camera.keep_aspect=Camera3D.KEEP_WIDTH;game.camera.size=saved_size*1.6
func accepts_point(point):return not active or art_rect.has_point(point)
func sync_shadows():
    for i in range(shadows.size()):
        var p=game.figures[i].position
        shadows[i].position=Vector3(p.x,0.008,p.z);shadows[i].visible=game.battle.units[i].hp>0
func _process(_delta):
    if active:fit();sync_shadows()
