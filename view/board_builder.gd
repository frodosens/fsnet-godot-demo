class_name BoardBuilder
extends RefCounted
const Architecture=preload("res://view/architecture.gd")
# Board geometry (terrain, landscape, river, bridge, inn, lamps, border props).
# It owns nothing but the nodes it adds to the host and the data it returns, so
# main.gd keeps only the camera, preview helpers and unit sprites.

var host: Node3D
var content
var size: Vector2i
var water_level = -1.15
var tiles = {}
var decorative_props = []

func add_child(node) -> void:
    host.add_child(node)

func _init(owner: Node3D, data) -> void:
    host = owner
    content = data
    size = Vector2i(data.width, data.height)

func build() -> Dictionary:
    for z in range(size.y):
        for x in range(size.x):
            var pos = Vector2i(x,z)
            var water = content.terrain[z][x]=="W"
            var bridge = content.terrain[z][x]=="B"
            var dirt=content.terrain[z][x]=="D"
            var color = "596d76" if water else ("85847a" if bridge else ("87775b" if dirt else ("59624b" if (x+z)%2 else "626a52")))
            var tile = box(Vector3(x,-0.15 if not water else water_level-0.06,z),Vector3(1.002,0.3 if not water else 0.12,1.002),color)
            var overlay=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(0.93,0.93);overlay.mesh=plane
            var highlight=StandardMaterial3D.new();highlight.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;highlight.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;highlight.albedo_color=Color(0.42,0.61,0.61,0.22)
            overlay.material_override=highlight;overlay.position=Vector3(x,0.012,z);overlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;overlay.visible=false;host.add_child(overlay)
            tiles[pos] = {"node":tile,"color":tile.material_override.albedo_color,"overlay":overlay}
    # Continuous non-playable landscape extends behind the authored tactical cells.
    # Only the bridge fixture's complete W/B rows get a continuous river strip.
    var river_rows=[]
    for z in range(size.y):
        var water_row=true;var has_water=false
        for c in content.terrain[z]:
            if c not in ["W","B"]:water_row=false
            if c=="W":has_water=true
        if water_row and has_water:river_rows.append(z)
    if not river_rows.is_empty():
        var start=river_rows[0]-0.5;var end=river_rows[-1]+0.5
        landscape_box(Vector3((size.x-1)*0.5,-0.28,(start-20)*0.5),Vector3(60,0.3,start+20),"59624b")
        landscape_box(Vector3((size.x-1)*0.5,-0.28,(end+30)*0.5),Vector3(60,0.3,30-end),"59624b")
        box(Vector3((size.x-1)*0.5,water_level-0.06,(start+end)*0.5),Vector3(60,0.12,end-start),"596d76")
        for pos in tiles:
            if content.terrain[pos.y][pos.x]=="W":tiles[pos].node.visible=false
        for x in range(-12,size.x+12):
            for edge in [start,end]:
                var near=clampi(int(edge+0.5 if edge==start else edge-0.5),0,size.y-1)
                if x>=0 and x<size.x and content.terrain[near][x]=="B":continue
                for course in range(3):
                    # Broken, staggered bank stones below the walk plane, not a canal parapet.
                    # Geometry is decorative; logical W/B cells remain unchanged.
                    if course==0 and posmod(x,5)==2:continue
                    var inset=0.12*sin(x*1.7+course*0.8)
                    var stone=box(Vector3(x+0.17*(course%2),-0.31-course*0.30+0.04*sin(x*2.1),edge+inset),Vector3(0.70+0.12*sin(x*2.4),0.24,0.26+0.10*absf(sin(x*1.3))),"a08e77")
                    stone.rotation.y=0.11*sin(x*1.9+course)
    else:
        landscape_box(Vector3(-10.5,-0.28,(size.y-1)*0.5),Vector3(20,0.3,60),"59624b")
        landscape_box(Vector3(size.x+9.5,-0.28,(size.y-1)*0.5),Vector3(20,0.3,60),"59624b")
        landscape_box(Vector3((size.x-1)*0.5,-0.28,-10.5),Vector3(size.x,0.3,20),"59624b")
        landscape_box(Vector3((size.x-1)*0.5,-0.28,size.y+9.5),Vector3(size.x,0.3,20),"59624b")
    # Bridge rails follow the data map; X cells are actual blocked obstacles.
    for z in range(size.y):
        for x in range(size.x):
            if content.terrain[z][x]=="X":
                if content.id=="amber_bridge_reference":
                    for rock in range(3):
                        var ruin=box(Vector3(x-0.25+rock*0.23,0.04+rock*0.02,z+0.15*sin(x+rock)),Vector3(0.34,0.23+0.04*rock,0.32),"84775f");ruin.rotation.y=0.25*rock
                else:box(Vector3(x,0.22,z),Vector3(0.8,0.6,0.8),"84775f")
            if content.terrain[z][x]=="B":
                for side in [-1,1]:
                    if x+side>=0 and x+side<size.x and content.terrain[z][x+side]=="W":
                        box(Vector3(x+side*0.47,0.13,z),Vector3(0.12,0.5,0.8),"a08e77")
    # Shallow stepped arch side supports below the walk plane. Geometry never changes grid rules.
    for x in range(size.x):
        var start=-1
        for z in range(size.y+1):
            var is_bridge=z<size.y and content.terrain[z][x]=="B"
            if is_bridge and start<0:start=z
            if not is_bridge and start>=0:
                var span=z-start
                for side in [-1,1]:
                    if x+side<0 or x+side>=size.x or content.terrain[start][x+side]!="W":continue
                    for piece in range(span*8):
                        var t=(piece+0.5)/(span*8.0)
                        var bottom=water_level+0.78*sin(t*PI)
                        var height=-0.15-bottom
                        box(Vector3(x+side*0.47,bottom+height*0.5,start-0.5+(piece+0.5)/8.0),Vector3(0.16,height,0.13),"a08e77")
                    for voussoir in range(12):
                        var t0= voussoir/12.0;var t1=(voussoir+0.94)/12.0
                        Architecture.arch_stone(self,x+side*0.49,start-0.5+span*t0,start-0.5+span*t1,water_level+0.78*sin(t0*PI),water_level+0.78*sin(t1*PI),voussoir%2)
                start=-1
    # Border-only irregular soil banks and river continuation: no traversable cells added.
    for z in range(size.y):
        for side in [-1,1]:
            var x=0 if side<0 else size.x-1
            if content.terrain[z][x]=="W":
                box(Vector3(x+side*1.0,water_level-0.06,z),Vector3(1.05,0.12,0.98),"596d76")
            else:
                var width=0.38+0.12*((z+2)%3)
                box(Vector3(x+side*(0.49+width*0.5),-0.20,z),Vector3(width,0.30,1.02),"59624b")
    for x in range(size.x):
        for z in [-0.83,size.y-0.17]:box(Vector3(x,-0.20,z),Vector3(1.02,0.30,0.66),"59624b")
    box(Vector3(-1.4,-0.18,6.6),Vector3(2.8,0.30,2.9),"87775b")
    var inn_start=host.get_child_count()
    # Small original roadside inn geometry using the authored environment albedos.
    box(Vector3(-1.1,0.6,6.7),Vector3(1.5,1.4,1.0),"8b887b")
    var roof=MeshInstance3D.new();var roof_shape=PrismMesh.new();roof_shape.size=Vector3(1.9,0.8,1.4)
    roof.mesh=roof_shape;roof.material_override=material("73594d");roof.position=Vector3(-1.1,1.7,6.7);host.add_child(roof)
    for x in [-1.8,-0.4]:box(Vector3(x,0.6,7.23),Vector3(0.09,1.4,0.07),"694d3b")
    box(Vector3(-1.1,1.22,7.23),Vector3(1.5,0.09,0.07),"694d3b")
    box(Vector3(-1.1,0.3,7.22),Vector3(0.38,0.8,0.04),"694d3b")
    for x in [-1.52,-0.65]: box(Vector3(x,0.85,7.23),Vector3(0.26,0.28,0.05),"d7b87d")
    box(Vector3(-1.55,1.85,6.45),Vector3(0.30,0.9,0.30),"a08e77")
    for x in [-1.52,-0.65]:
        for side in [-1,1]:box(Vector3(x+side*0.17,0.85,7.26),Vector3(0.06,0.38,0.06),"694d3b")
        box(Vector3(x,0.62,7.28),Vector3(0.40,0.08,0.10),"694d3b")
        box(Vector3(x,0.85,7.285),Vector3(0.025,0.28,0.025),"694d3b")
        box(Vector3(x,0.85,7.285),Vector3(0.26,0.025,0.025),"694d3b")
    Architecture.inn_details(self)
    var inn_nodes=host.get_children().slice(inn_start)
    var inn=Node3D.new();inn.position=Vector3(-1.1,0,6.7);host.add_child(inn)
    for node in inn_nodes:node.reparent(inn,true)
    inn.scale=Vector3.ONE*1.65;inn.position.x=-2.3;inn.position.z=size.y-1.3
    for window_x in [-1.52,-0.65]:
        var glow=OmniLight3D.new();glow.position=inn.to_global(Vector3(window_x+1.1,0.85,0.58));glow.light_color=Color("ffb568");glow.light_energy=0.65;glow.omni_range=2.4;glow.shadow_enabled=true;host.add_child(glow)
    for p in [Vector3(3.35,0,size.y-2.9),Vector3(5.65,0,2.3)]:
        box(p+Vector3(0,0.5,0),Vector3(0.08,1,0.08),"594633")
        var lamp = OmniLight3D.new()
        lamp.position = p+Vector3(0,1,0)
        lamp.light_color = Color("ceab7c")
        lamp.light_energy = 1.1
        lamp.omni_range = 3.5
        lamp.shadow_enabled = true
        host.add_child(lamp)
        var glass=box(p+Vector3(0,1,0),Vector3(0.18,0.26,0.18),"ce9a57")
        glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        glass.material_override.emission_enabled=true;glass.material_override.emission=Color("ffb45c");glass.material_override.emission_energy_multiplier=1.4
        for edge in [-1,1]:
            for side in [-1,1]:
                var frame=box(p+Vector3(edge*0.10,1,side*0.10),Vector3(0.025,0.32,0.025),"594633");frame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var cap=box(p+Vector3(0,1.18,0),Vector3(0.26,0.05,0.26),"594633");cap.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return tiles

func build_props() -> void:
    # Border-only decor; never adds traversable cells or changes the data map.
    var path="res://assets/environment/props_v3/manifest.json"
    if not FileAccess.file_exists(path):return
    var definitions=JSON.parse_string(FileAccess.get_file_as_string(path)).props
    var foliage_path="res://assets/environment/foliage_v4/manifest.json"
    var foliage={}
    if FileAccess.file_exists(foliage_path):foliage=JSON.parse_string(FileAccess.get_file_as_string(foliage_path)).get("props",{})
    var placements=[["tree",Vector2(3.5,-1.35)],["tree",Vector2(size.x-3,-1.5)],["tree",Vector2(-1.5,1.5)],["shrub",Vector2(3,-0.9)],["shrub",Vector2(size.x+0.15,1.4)],["shrub",Vector2(size.x-1,size.y+0.05)],["reeds_rocks",Vector2(-0.8,3.0)],["reeds_rocks",Vector2(size.x+0.2,4.0)],["supplies",Vector2(-1.8,7.55)],["lantern",Vector2(-0.2,7.8)]]
    for x in range(-4,size.x+5):
        placements.append(["tree",Vector2(x+0.5*sin(x*1.7),-3.3-0.6*((x+8)%3))])
        if x<1 or x>size.x-3:placements.append(["tree",Vector2(x+0.5*cos(x*1.3),size.y+2.4+0.4*sin(x))])
    for z in range(-1,size.y+2,2):
        var river_row=z>=0 and z<size.y and content.terrain[z].replace("W","").replace("B","").is_empty()
        if not river_row:
            placements.append(["tree",Vector2(-3.0-0.3*sin(z),z)]);placements.append(["tree",Vector2(size.x+2.0+0.3*cos(z),z)])
    placements.append(["tree",Vector2(-2.5,6.3)]);placements.append(["tree",Vector2(size.x+2,6.3)])
    for x in range(-3,size.x+3):
        for z in [-0.8,size.y-0.15]:
            placements.append(["shrub",Vector2(x+0.2*sin(x*1.4),z)])
            if x%2==0:placements.append(["reeds_rocks",Vector2(x,size.y-4.45)])
    if content.id=="amber_bridge_reference":
        for z in range(size.y):
            for x in range(size.x):
                if content.terrain[z][x]=="X":placements.append(["shrub",Vector2(x,z)])
    for placement in placements:
        var cell=placement[1]
        var inside=cell.x>=-0.5 and cell.x<size.x-0.5 and cell.y>=-0.5 and cell.y<size.y-0.5
        if inside and (placement[0] not in ["tree","shrub"] or content.terrain[roundi(cell.y)][roundi(cell.x)]!="X"):continue
        var species=placement[0]
        if not foliage.is_empty():
            if species=="tree":
                var pick=posmod(roundi(cell.x*7+cell.y*3),4)
                species=["oak","birch","conifer","birch"][pick]
                if cell.y>=2 and cell.y<=6.5:species="willow"
                # Keep large crowns outside the tactical area, rather than hiding units behind cards.
                if cell.x<0:cell.x=minf(cell.x,-2.4)
                elif cell.x>=size.x:cell.x=maxf(cell.x,size.x+1.8)
                if cell.y<0:cell.y=minf(cell.y,-2.4)
                elif cell.y>=size.y:cell.y=maxf(cell.y,size.y+1.8)
            elif species=="shrub":species="shrub_round" if inside or posmod(roundi(cell.x*3+cell.y),2)==0 else "shrub_tall"
        var d=foliage.get(species,definitions[placement[0]]);var sprite=Sprite3D.new();sprite.texture=load("res://"+d.path);sprite.pixel_size=d.pixel_size
        sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.shaded=true;sprite.modulate=Color.WHITE;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
        sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=0.5;sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        var base_y=water_level+0.08 if placement[0]=="reeds_rocks" else (-0.13 if placement[0]=="tree" else -0.03)
        if placement[0]=="tree" and (cell.x<-2 or cell.x>size.x+1 or cell.y<-2 or cell.y>size.y+1):
            var variation=0.95+0.12*sin(cell.x*2.3+cell.y);sprite.pixel_size*=variation
            sprite.modulate=Color(0.65,0.76,0.72)
        sprite.position=Vector3(cell.x,base_y+(d.pivot_px[1]-128)*sprite.pixel_size,cell.y);sprite.set_meta("decorative_kind",placement[0]);sprite.set_meta("species",species);sprite.set_meta("ground_cell",cell);sprite.set_meta("alpha_bbox",d.get("alpha_bbox_px",[0,0,256,256]));host.add_child(sprite);decorative_props.append(sprite)


func material(color):
    var m = StandardMaterial3D.new()
    var kinds={"87775b":"dirt","59624b":"grass","626a52":"grass","596d76":"water","85847a":"stone_paving","a08e77":"stone_wall","84775f":"stone_wall","8b887b":"plaster","73594d":"roof","694d3b":"wood","594633":"wood"}
    var path="res://assets/environment/v2/"+str(kinds.get(color,""))+".png"
    var textured=ResourceLoader.exists(path)
    m.albedo_color=Color.WHITE if textured else Color(color)
    if textured:
        m.albedo_texture=load(path);m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
        m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_triplanar_sharpness=8.0
    m.roughness=0.28 if color=="596d76" else 1.0;m.metallic_specular=0.45 if color=="596d76" else 0.0
    return m


func box(pos,size,color):
    var mesh = MeshInstance3D.new()
    var shape = BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    mesh.material_override = material(color)
    mesh.position = pos
    host.add_child(mesh)
    return mesh


func landscape_box(pos,size,color):
    var node=box(pos,size,color)
    node.material_override.albedo_color=Color(0.55,0.64,0.58)
    return node

