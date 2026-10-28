extends MeshInstance3D
# Ground-space geometry, depth-tested against opaque/discard character pixels.
# Pixel-sized strokes are unprojected back onto the same ground plane as the range.
var game
var targeting={}
var targeting_signature=""
const Targeting=preload("res://view/targeting_preview.gd")
var art_route_enabled=true # Candidate can revert to the previous ribbon without changing rules.
var route_art=preload("res://view/route_art.gd").new()
var art_parts=[]
var cells:MeshInstance3D
var ground_materials={}
var signature=""
var building=false
var last_path=[]
var reveal=0.0
var route_length=0.0
var clock=0.0
const HEIGHT=0.025
func _ready():
    mesh=ImmediateMesh.new();cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo=true;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.render_priority=1
    material_override=mat
    cells=MeshInstance3D.new();cells.mesh=ImmediateMesh.new();cells.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(cells)
    for name in ["target_cell_border_gold","route_arrowhead_ivory"]:
        var m=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.cull_mode=BaseMaterial3D.CULL_DISABLED
        m.albedo_texture=load("res://assets/ui/bottom_dock_reference/ground/"+name+".png");m.render_priority=1;ground_materials[name]=m
func textured_quad(points,material):
    cells.mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,ground_materials[material])
    var uv=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
    for index in [0,1,2,0,2,3]:cells.mesh.surface_set_uv(uv[index]);cells.mesh.surface_add_vertex(points[index])
    cells.mesh.surface_end()
func tile_quad(cell,material,height):
    var points=[]
    for c in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:points.append(Vector3(cell.x+c.x,height,cell.y+c.y))
    textured_quad(points,material)
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
# Round only inside the turn cell: radius < half a tile. No shortcut across blocked neighbours.
func rounded_route(path):
    var result=[]
    if path.size()<2:return result
    result.append(Vector2(path[0].x,path[0].y))
    for i in range(1,path.size()-1):
        var previous=Vector2(path[i-1].x,path[i-1].y);var current=Vector2(path[i].x,path[i].y);var next=Vector2(path[i+1].x,path[i+1].y)
        var incoming=(current-previous).normalized();var outgoing=(next-current).normalized()
        if absf(incoming.dot(outgoing))>0.99:result.append(current);continue
        var a=current-incoming*0.20;var b=current+outgoing*0.20
        result.append(a)
        for sample in range(1,9):
            var t=sample/8.0;result.append(a.lerp(current,t).lerp(current.lerp(b,t),t))
    result.append(Vector2(path[-1].x,path[-1].y))
    return result
func prefix(points,length):
    var result=[]
    if points.is_empty():return result
    result.append(points[0])
    for i in range(points.size()-1):
        var distance=points[i].distance_to(points[i+1])
        if length<=0:break
        result.append(points[i].lerp(points[i+1],minf(1,length/maxf(distance,0.0001))))
        length-=distance
    return result
func ribbon(points,width,color):
    # Shared vertices at each join prevent translucent overlapping segment seams.
    if points.size()<2:return
    var left=[];var right=[]
    for i in range(points.size()):
        var before=(points[i]-points[maxi(0,i-1)]).normalized()
        var after=(points[mini(points.size()-1,i+1)]-points[i]).normalized()
        if i==0:before=after
        if i==points.size()-1:after=before
        var tangent=(before+after).normalized()
        if tangent.length_squared()<0.1:tangent=after
        var normal=Vector2(-tangent.y,tangent.x)
        var segment_normal=Vector2(-after.y,after.x)
        var offset=normal*(width*0.5/maxf(0.75,absf(normal.dot(segment_normal))))
        left.append(points[i]+offset);right.append(points[i]-offset)
    for i in range(points.size()-1):
        triangle(left[i],left[i+1],right[i+1],color);triangle(left[i],right[i+1],right[i],color)
# Reachable values are shortest-path costs supplied by shared Lua, not screen radii.
func range_alpha(cost,max_cost,time,reduced):
    var layer=clampf(float(cost)/maxf(1.0,float(max_cost)),0.0,1.0)
    var breath=1.0 if reduced else 0.94+0.06*sin(time*TAU/3.2)
    return Vector2(maxf(0.50,lerpf(0.78,0.56,layer)*breath),lerpf(0.66,0.34,layer)*breath)
func draw_range():
    var max_cost=1.0
    for value in game.preview_reachable.values():max_cost=maxf(max_cost,float(value))
    var edges={}
    for cell in game.preview_reachable:
        if cell==game.battle.units[game.selected].pos:continue
        var alpha=range_alpha(game.preview_reachable[cell],max_cost,clock,App.reduced_motion)
        var corners=[]
        for offset in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:corners.append(Vector2(cell)+offset)
        var fill=Color(0.24,0.73,0.76,alpha.x)
        triangle(projected(corners[0]),projected(corners[1]),projected(corners[2]),fill)
        triangle(projected(corners[0]),projected(corners[2]),projected(corners[3]),fill)
        for i in range(4):
            var a=corners[i];var b=corners[(i+1)%4]
            if a.x>b.x or (a.x==b.x and a.y>b.y):var swap=a;a=b;b=swap
            var key=str(a)+":"+str(b)
            if not edges.has(key):edges[key]=[a,b,alpha.y]
            else:edges[key][2]=maxf(edges[key][2],alpha.y)
    for edge in edges.values():stroke(projected(edge[0]),projected(edge[1]),1.4,Color(0.40,0.88,0.89,edge[2]))
func fill_cell(cell,color):
    var points=[]
    for offset in [Vector2(-0.46,-0.46),Vector2(0.46,-0.46),Vector2(0.46,0.46),Vector2(-0.46,0.46)]:points.append(projected(Vector2(cell)+offset))
    triangle(points[0],points[1],points[2],color);triangle(points[0],points[2],points[3],color)
func draw_targeting():
    if not targeting.get("active",false):return
    # Dim cast-distance envelope is not a promise of LOS, faction or resource legality.
    for cell in targeting.cast_cells:fill_cell(cell,Color(0.30,0.55,0.82,0.18))
    for cell in targeting.area_cells:fill_cell(cell,Color(1.0,0.65,0.22,0.38))
    for cell in targeting.legal_cells:tile_quad(cell,"target_cell_border_gold",HEIGHT+0.004)
    if targeting.hover.x>=0 and targeting.hover.y>=0 and not targeting.hover_legal and targeting.hover.x<game.battle.size.x and targeting.hover.y<game.battle.size.y:
        fill_cell(targeting.hover,Color(0.9,0.22,0.22,0.35))
func focus_marker():
    if game.hud.action_menu_open or game.targeting_locked():return {}
    if game.mode=="move":
        var cell=game.pending_move.get("cell",game.preview_cell)
        if cell.x>=0 and cell.y>=0 and cell.x<game.battle.size.x and cell.y<game.battle.size.y:
            return {"cell":cell,"valid":not game.preview_path.is_empty()}
    elif targeting.get("active",false):
        var cell=targeting.hover
        if cell.x>=0 and cell.y>=0 and cell.x<game.battle.size.x and cell.y<game.battle.size.y:
            return {"cell":cell,"valid":targeting.hover_legal}
    return {}
func draw_focus_marker():
    var marker=focus_marker()
    if marker.is_empty():return
    var pulse=1.0 if App.reduced_motion else 0.88+0.12*sin(clock*TAU/1.8)
    var ink=Color(1.0,0.87,0.40,pulse) if marker.valid else Color(1.0,0.28,0.20,pulse)
    var corners=[]
    for offset in [Vector2(-0.48,-0.48),Vector2(0.48,-0.48),Vector2(0.48,0.48),Vector2(-0.48,0.48)]:corners.append(projected(Vector2(marker.cell)+offset))
    for i in range(4):
        var a=corners[i];var b=corners[(i+1)%4]
        stroke(a,b,5,Color(0.08,0.10,0.12,0.95));stroke(a,b,2,ink)
    for i in range(4):
        var a=corners[i]
        for neighbour in [(i+3)%4,(i+1)%4]:
            var b=a.lerp(corners[neighbour],0.28)
            stroke(a,b,9,Color(0.08,0.10,0.12,0.95));stroke(a,b,5,ink)

func targeting_state():
    var target_key=str([game.mode,game.selected,game.battle.get_instance_id(),game.battle.step,game.battle.content_hash,game.target_hover_cell,game.pending_target.get("cell",Vector2i(-1,-1)),game.hud.action_menu_open,game.targeting_locked()])
    if target_key!=targeting_signature:
        targeting_signature=target_key;targeting=Targeting.describe(game)
    return targeting
func _process(delta):
    clock+=delta
    targeting_state()
    var path=game.preview_path if game.preview_path is Array and not game.presentation_active() else []
    if path!=last_path:
        var common=0
        while common<mini(path.size(),last_path.size()) and path[common]==last_path[common]:common+=1
        reveal=minf(reveal,maxf(0,common-1.0));last_path=path.duplicate(true)
        art_parts=route_art.plan(path)
    var route=rounded_route(path);route_length=0.0
    for i in range(route.size()-1):route_length+=route[i].distance_to(route[i+1])
    reveal=route_length if App.reduced_motion else minf(route_length,reveal+delta*18.0)
    var animated=(not focus_marker().is_empty() or route_length>0 or (game.mode=="move" and not game.preview_reachable.is_empty())) and not App.reduced_motion
    var tick=int(clock*30.0) if animated else 0
    var state=str([game.mode,game.selected,game.battle.step,path,game.preview_reachable,game.preview_cell,game.preview_reason,game.presentation_active(),game.hud.action_menu_open,game.camera.global_transform,game.camera.size,game.camera.keep_aspect,targeting_signature,art_route_enabled,get_viewport().get_visible_rect(),tick])
    if state==signature:return
    signature=state;mesh.clear_surfaces();cells.mesh.clear_surfaces();building=false
    if game.presentation_active():return
    draw_targeting()
    if game.mode=="move" and not game.hud.action_menu_open and game.selected>=0 and game.battle.usable(game.selected) and not game.battle.units[game.selected].moved:
        draw_range()
    if route.size()>=2 and art_route_enabled and route_art.ready:
        route_art.draw(cells.mesh,art_parts,HEIGHT+0.004,1.0 if App.reduced_motion else clampf(reveal/maxf(route_length,.001),0.0,1.0))
    elif route.size()>=2:
        var points=[]
        for cell in prefix(route,reveal):points.append(projected(cell))
        if points.size()>=2:
            ribbon(points,9,Color("23332f"));ribbon(points,5,Color("e4c58a"))
            # One continuous arrow, not a chain of detached per-cell arrows.
            var tip=points[-1];var direction=(tip-points[-2]).normalized();var normal=Vector2(-direction.y,direction.x)
            var arrow=[]
            for p in [tip-direction*24-normal*10,tip+direction*4-normal*10,tip+direction*4+normal*10,tip-direction*24+normal*10]:arrow.append(ground(p)+Vector3(0,0.002,0))
            textured_quad(arrow,"route_arrowhead_ivory")
            if not App.reduced_motion and reveal>=route_length:
                var travel=fmod(clock*0.8,route_length)
                var highlight=prefix(route,minf(route_length,travel+0.20))
                var begin=prefix(route,travel)
                if not begin.is_empty():
                    var segment=[projected(begin[-1])]
                    # A short travelling sheen follows the exact rounded polyline.
                    var total=0.0
                    for i in range(route.size()-1):
                        total+=route[i].distance_to(route[i+1])
                        if total>travel and total<travel+0.20:segment.append(projected(route[i+1]))
                    segment.append(projected(highlight[-1]));ribbon(segment,2,Color(1,0.93,0.73,0.7))
        tile_quad(route[-1],"target_cell_border_gold",HEIGHT+0.004)
    draw_focus_marker()
    if building:mesh.surface_end()
