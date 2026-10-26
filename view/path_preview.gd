extends MeshInstance3D
# Ground-space geometry, depth-tested against opaque/discard character pixels.
# Pixel-sized strokes are unprojected back onto the same ground plane as the range.
var game
var signature=""
var building=false
const HEIGHT=0.025
func _ready():
    mesh=ImmediateMesh.new();cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo=true;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.render_priority=1
    material_override=mat
func ground(point):
    var origin=game.camera.project_ray_origin(point);var ray=game.camera.project_ray_normal(point)
    return origin+ray*((HEIGHT-origin.y)/ray.y)
func projected(cell):return game.camera.unproject_position(Vector3(cell.x,HEIGHT,cell.y))
func triangle(a,b,c,color):
    if not building:mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES);building=true
    for point in [a,b,c]:mesh.surface_set_color(color);mesh.surface_add_vertex(ground(point))
func stroke(a,b,width,color):
    if a.distance_squared_to(b)<0.001:return
    var normal=Vector2(-(b-a).y,(b-a).x).normalized()*width*0.5
    triangle(a+normal,b+normal,b-normal,color);triangle(a+normal,b-normal,a-normal,color)
func polyline(points,width,color):
    for i in range(points.size()-1):stroke(points[i],points[i+1],width,color)
func _process(_delta):
    var state=str([game.mode,game.selected,game.battle.step,game.preview_path,game.preview_reachable,game.presentation_active(),game.camera.global_transform,game.camera.size,game.camera.keep_aspect,get_viewport().get_visible_rect()])
    if state==signature:return
    signature=state;mesh.clear_surfaces();building=false
    if game.presentation_active():return
    if game.mode=="move" and game.selected>=0 and game.battle.usable(game.selected) and not game.battle.units[game.selected].moved:
        for cell in game.preview_reachable:
            if cell==game.battle.units[game.selected].pos:continue
            var outline=[]
            for corner in [Vector2(-0.46,-0.46),Vector2(0.46,-0.46),Vector2(0.46,0.46),Vector2(-0.46,0.46),Vector2(-0.46,-0.46)]:outline.append(projected(Vector2(cell)+corner))
            polyline(outline,1.0,Color(0.42,0.61,0.61,0.55))
    if game.preview_path.size()>=2:
        var points=[]
        for cell in game.preview_path:points.append(projected(Vector2(cell.x,cell.y)))
        polyline(points,6,Color("23332f"));polyline(points,3,Color("e4c58a"))
        var circle=[]
        for i in range(25):circle.append(points[0]+Vector2(cos(TAU*i/24.0),sin(TAU*i/24.0))*8)
        polyline(circle,2,Color("e4c58a"))
        for i in range(points.size()-1):
            var direction=(points[i+1]-points[i]).normalized();var side=Vector2(-direction.y,direction.x)*4
            var tip=points[i].lerp(points[i+1],0.72)
            triangle(tip,tip-direction*9+side,tip-direction*9-side,Color("eee2c6"))
        var end=points[-1]
        polyline([end+Vector2(0,-12),end+Vector2(12,0),end+Vector2(0,12),end+Vector2(-12,0),end+Vector2(0,-12)],2,Color("dfa75f"))
    if building:mesh.surface_end()
