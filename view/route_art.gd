extends RefCounted
# Exact regions of the approved top-down atlas; no generated/repainted pixels.
const SOURCE="res://assets/ui/path_route/runtime-arrow-modules.png"
const PIXEL_SCALE=0.12/56.0
const REGIONS={"straight":Rect2(150,202,340,63),"corner":Rect2(596,140,194,182),"head":Rect2(950,156,211,152),"start":Rect2(1220,190,110,83),"end":Rect2(1505,133,202,202)}
static var textures={}
var materials={}
var ready=false
func _init():
    if not ResourceLoader.exists(SOURCE):return
    var source=load(SOURCE)
    if not source is Texture2D or source.get_size()!=Vector2(1774,400):return
    if textures.is_empty():
        var image=source.get_image()
        for key in REGIONS:textures[key]=ImageTexture.create_from_image(image.get_region(Rect2i(REGIONS[key])))
    for key in REGIONS:
        var texture=textures[key]
        var m=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.cull_mode=BaseMaterial3D.CULL_DISABLED;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
        m.albedo_texture=texture;m.render_priority=2;materials[key]=m
    ready=true
func valid_path(path):
    if not path is Array or path.size()<2:return false
    for i in range(path.size()):
        if not path[i] is Dictionary or not path[i].has("x") or not path[i].has("y"):return false
        for axis in ["x","y"]:
            var value=path[i][axis]
            if not (value is int or value is float) or not is_finite(value) or value!=floor(value):return false
        if i>0 and abs(path[i].x-path[i-1].x)+abs(path[i].y-path[i-1].y)!=1:return false
    return true
func piece(kind,center,xaxis,yaxis,pivot):
    var r=REGIONS[kind];var points=[]
    for p in [r.position,r.position+Vector2(r.size.x,0),r.end,r.position+Vector2(0,r.size.y)]:points.append(center+xaxis*(p.x-pivot.x)*PIXEL_SCALE+yaxis*(p.y-pivot.y)*PIXEL_SCALE)
    return {"kind":kind,"points":points}
func plan(path):
    var result=[]
    if not valid_path(path):return result
    var p=[]
    for cell in path:p.append(Vector2(cell.x,cell.y))
    var enter={};var leave={}
    var first=(p[1]-p[0]).normalized();var first_side=Vector2(-first.y,first.x)
    result.append(piece("start",p[0],first,first_side,Vector2(1255,233)))
    leave[0]=75*PIXEL_SCALE
    for i in range(1,p.size()-1):
        var incoming=(p[i]-p[i-1]).normalized();var outgoing=(p[i+1]-p[i]).normalized()
        if absf(incoming.dot(outgoing))<.01:
            result.append(piece("corner",p[i],outgoing,incoming,Vector2(629,288)))
            enter[i]=148*PIXEL_SCALE;leave[i]=161*PIXEL_SCALE
    var final=(p[-1]-p[-2]).normalized();var side=Vector2(-final.y,final.x)
    result.append(piece("head",p[-1],final,side,Vector2(1155,232)))
    enter[p.size()-1]=205*PIXEL_SCALE
    for i in range(p.size()-1):
        var d=(p[i+1]-p[i]).normalized();var n=Vector2(-d.y,d.x)
        var a=p[i]+d*float(leave.get(i,0));var b=p[i+1]-d*float(enter.get(i+1,0))
        if (b-a).dot(d)<=0:continue
        # Open ports meet at identical world coordinates; no overlapping dark caps.
        var top=(202-233)*PIXEL_SCALE;var bottom=(265-233)*PIXEL_SCALE
        result.append({"kind":"straight","points":[a+n*top,b+n*top,b+n*bottom,a+n*bottom]})
    # Endpoint is a square on the ground, projected once by the scene camera.
    var half=.43
    result.append({"kind":"end","points":[p[-1]+Vector2(-half,-half),p[-1]+Vector2(half,-half),p[-1]+Vector2(half,half),p[-1]+Vector2(-half,half)]})
    return result
func draw(mesh,parts,height,opacity=1.0):
    if not ready:return
    for part in parts:
        var material=materials[part.kind];material.albedo_color.a=clampf(opacity,0,1)
        mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
        var uv=[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
        for i in [0,1,2,0,2,3]:
            mesh.surface_set_uv(uv[i]);var p=part.points[i];mesh.surface_add_vertex(Vector3(p.x,height,p.y))
        mesh.surface_end()
