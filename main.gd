extends Node3D
const Session = preload("res://logic/session.gd")
var session
const Architecture=preload("res://view/architecture.gd")
const Hud=preload("res://ui/battle_hud.gd")
var hud
var cutin
var heal_feedback
var motion
var battle
var last_step = -1
var network_label: Label
var selected = 0
var mode = "move"
var camera: Camera3D
var tiles = {}
var figures = []
var badges = []
var status: Label
var detail: Label
var message: Label
var buttons = []
var facing={}
var last_positions={}
var direction_textures={}
var iso_roles={}
var target_preview={}
var target_preview_index=-1
var preview_reason=""
var preview_reachable={}
var pending_move={}
var pending_target={}
var preview_path=[]
var preview_cell=Vector2i(-1,-1)
var route_mesh
var decorative_props=[]
var water_level=-1.15
var preview_ghost
var route_arrows
var selection_ring
var scene_view
var ground_overlay
const MAP_PIXEL_SIZE=0.010727272727 # 99px Mara -> 90 logical px in reference camera at 1.25 scale.
var character_scale=1.0

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
    add_child(mesh)
    return mesh

func _ready():
    if not App.session:App.new_game()
    session=App.session
    battle = session.logic
    build_world()
    ground_overlay=preload("res://view/path_preview.gd").new();ground_overlay.game=self;add_child(ground_overlay)
    build_hud()
    scene_view=preload("res://view/fixed_background.gd").new();scene_view.game=self;add_child(scene_view)
    if App.scene_renderer in ["auto","fixed"]:scene_view.set_fixed(true)
    var idle=preload("res://view/map_idle.gd").new();idle.name="MapIdle";idle.game=self;add_child(idle)
    refresh()
    print("PROTOTYPE_READY shared_lua=true units=",figures.size()," tiles=",tiles.size()," renderer=",RenderingServer.get_video_adapter_name())
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture="):
            if DisplayServer.get_name()=="headless":
                printerr("Capture requires a real rendering display, not dummy.")
                get_tree().quit(1)
                return
            for frame in range(8): await get_tree().process_frame
            await RenderingServer.frame_post_draw
            var result=get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture="))
            print("RENDER_CAPTURE result=",result," adapter=",RenderingServer.get_video_adapter_name())
            get_tree().quit(0 if result==OK else 1)
    if "--scene-smoke" in OS.get_cmdline_user_args():
        await get_tree().process_frame
        if figures.size() != battle.units.size() or tiles.size() != battle.size.x*battle.size.y:
            get_tree().quit(1)
        else:
            print("SCENE_SMOKE_OK (scene construction only; no visual assertion)")
            get_tree().quit(0)

func build_world():
    var environment = WorldEnvironment.new()
    var settings = Environment.new()
    settings.background_mode = Environment.BG_COLOR
    settings.background_color = Color("172b36")
    settings.fog_enabled=true;settings.fog_light_color=Color("253d4a");settings.fog_density=0.009
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color("8babc2")
    settings.ambient_light_energy = 0.24
    environment.environment = settings
    add_child(environment)
    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48,-35,0)
    sun.light_color = Color("f3d6a1")
    sun.light_energy = 0.72
    sun.shadow_enabled = true
    add_child(sun)
    for z in range(battle.size.y):
        for x in range(battle.size.x):
            var pos = Vector2i(x,z)
            var water = battle.content.terrain[z][x]=="W"
            var bridge = battle.content.terrain[z][x]=="B"
            var dirt=battle.content.terrain[z][x]=="D"
            var color = "596d76" if water else ("85847a" if bridge else ("87775b" if dirt else ("59624b" if (x+z)%2 else "626a52")))
            var tile = box(Vector3(x,-0.15 if not water else water_level-0.06,z),Vector3(1.002,0.3 if not water else 0.12,1.002),color)
            var overlay=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(0.93,0.93);overlay.mesh=plane
            var highlight=StandardMaterial3D.new();highlight.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;highlight.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;highlight.albedo_color=Color(0.42,0.61,0.61,0.22)
            overlay.material_override=highlight;overlay.position=Vector3(x,0.012,z);overlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;overlay.visible=false;add_child(overlay)
            tiles[pos] = {"node":tile,"color":tile.material_override.albedo_color,"overlay":overlay}
    # Continuous non-playable landscape extends behind the authored tactical cells.
    # Only the bridge fixture's complete W/B rows get a continuous river strip.
    var river_rows=[]
    for z in range(battle.size.y):
        var water_row=true;var has_water=false
        for c in battle.content.terrain[z]:
            if c not in ["W","B"]:water_row=false
            if c=="W":has_water=true
        if water_row and has_water:river_rows.append(z)
    if not river_rows.is_empty():
        var start=river_rows[0]-0.5;var end=river_rows[-1]+0.5
        landscape_box(Vector3((battle.size.x-1)*0.5,-0.28,(start-20)*0.5),Vector3(60,0.3,start+20),"59624b")
        landscape_box(Vector3((battle.size.x-1)*0.5,-0.28,(end+30)*0.5),Vector3(60,0.3,30-end),"59624b")
        box(Vector3((battle.size.x-1)*0.5,water_level-0.06,(start+end)*0.5),Vector3(60,0.12,end-start),"596d76")
        for pos in tiles:
            if battle.content.terrain[pos.y][pos.x]=="W":tiles[pos].node.visible=false
        for x in range(-12,battle.size.x+12):
            for edge in [start,end]:
                var near=clampi(int(edge+0.5 if edge==start else edge-0.5),0,battle.size.y-1)
                if x>=0 and x<battle.size.x and battle.content.terrain[near][x]=="B":continue
                for course in range(3):
                    # Broken, staggered bank stones below the walk plane, not a canal parapet.
                    # Geometry is decorative; logical W/B cells remain unchanged.
                    if course==0 and posmod(x,5)==2:continue
                    var inset=0.12*sin(x*1.7+course*0.8)
                    var stone=box(Vector3(x+0.17*(course%2),-0.31-course*0.30+0.04*sin(x*2.1),edge+inset),Vector3(0.70+0.12*sin(x*2.4),0.24,0.26+0.10*absf(sin(x*1.3))),"a08e77")
                    stone.rotation.y=0.11*sin(x*1.9+course)
    else:
        landscape_box(Vector3(-10.5,-0.28,(battle.size.y-1)*0.5),Vector3(20,0.3,60),"59624b")
        landscape_box(Vector3(battle.size.x+9.5,-0.28,(battle.size.y-1)*0.5),Vector3(20,0.3,60),"59624b")
        landscape_box(Vector3((battle.size.x-1)*0.5,-0.28,-10.5),Vector3(battle.size.x,0.3,20),"59624b")
        landscape_box(Vector3((battle.size.x-1)*0.5,-0.28,battle.size.y+9.5),Vector3(battle.size.x,0.3,20),"59624b")
    # Bridge rails follow the data map; X cells are actual blocked obstacles.
    for z in range(battle.size.y):
        for x in range(battle.size.x):
            if battle.content.terrain[z][x]=="X":
                if battle.content.id=="amber_bridge_reference":
                    for rock in range(3):
                        var ruin=box(Vector3(x-0.25+rock*0.23,0.04+rock*0.02,z+0.15*sin(x+rock)),Vector3(0.34,0.23+0.04*rock,0.32),"84775f");ruin.rotation.y=0.25*rock
                else:box(Vector3(x,0.22,z),Vector3(0.8,0.6,0.8),"84775f")
            if battle.content.terrain[z][x]=="B":
                for side in [-1,1]:
                    if x+side>=0 and x+side<battle.size.x and battle.content.terrain[z][x+side]=="W":
                        box(Vector3(x+side*0.47,0.13,z),Vector3(0.12,0.5,0.8),"a08e77")
    # Shallow stepped arch side supports below the walk plane. Geometry never changes grid rules.
    for x in range(battle.size.x):
        var start=-1
        for z in range(battle.size.y+1):
            var is_bridge=z<battle.size.y and battle.content.terrain[z][x]=="B"
            if is_bridge and start<0:start=z
            if not is_bridge and start>=0:
                var span=z-start
                for side in [-1,1]:
                    if x+side<0 or x+side>=battle.size.x or battle.content.terrain[start][x+side]!="W":continue
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
    for z in range(battle.size.y):
        for side in [-1,1]:
            var x=0 if side<0 else battle.size.x-1
            if battle.content.terrain[z][x]=="W":
                box(Vector3(x+side*1.0,water_level-0.06,z),Vector3(1.05,0.12,0.98),"596d76")
            else:
                var width=0.38+0.12*((z+2)%3)
                box(Vector3(x+side*(0.49+width*0.5),-0.20,z),Vector3(width,0.30,1.02),"59624b")
    for x in range(battle.size.x):
        for z in [-0.83,battle.size.y-0.17]:box(Vector3(x,-0.20,z),Vector3(1.02,0.30,0.66),"59624b")
    box(Vector3(-1.4,-0.18,6.6),Vector3(2.8,0.30,2.9),"87775b")
    var inn_start=get_child_count()
    # Small original roadside inn geometry using the authored environment albedos.
    box(Vector3(-1.1,0.6,6.7),Vector3(1.5,1.4,1.0),"8b887b")
    var roof=MeshInstance3D.new();var roof_shape=PrismMesh.new();roof_shape.size=Vector3(1.9,0.8,1.4)
    roof.mesh=roof_shape;roof.material_override=material("73594d");roof.position=Vector3(-1.1,1.7,6.7);add_child(roof)
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
    var inn_nodes=get_children().slice(inn_start)
    var inn=Node3D.new();inn.position=Vector3(-1.1,0,6.7);add_child(inn)
    for node in inn_nodes:node.reparent(inn,true)
    inn.scale=Vector3.ONE*1.65;inn.position.x=-2.3;inn.position.z=battle.size.y-1.3
    for window_x in [-1.52,-0.65]:
        var glow=OmniLight3D.new();glow.position=inn.to_global(Vector3(window_x+1.1,0.85,0.58));glow.light_color=Color("ffb568");glow.light_energy=0.65;glow.omni_range=2.4;glow.shadow_enabled=true;add_child(glow)
    for p in [Vector3(3.35,0,battle.size.y-2.9),Vector3(5.65,0,2.3)]:
        box(p+Vector3(0,0.5,0),Vector3(0.08,1,0.08),"594633")
        var lamp = OmniLight3D.new()
        lamp.position = p+Vector3(0,1,0)
        lamp.light_color = Color("ceab7c")
        lamp.light_energy = 1.1
        lamp.omni_range = 3.5
        lamp.shadow_enabled = true
        add_child(lamp)
        var glass=box(p+Vector3(0,1,0),Vector3(0.18,0.26,0.18),"ce9a57")
        glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        glass.material_override.emission_enabled=true;glass.material_override.emission=Color("ffb45c");glass.material_override.emission_energy_multiplier=1.4
        for edge in [-1,1]:
            for side in [-1,1]:
                var frame=box(p+Vector3(edge*0.10,1,side*0.10),Vector3(0.025,0.32,0.025),"594633");frame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var cap=box(p+Vector3(0,1.18,0),Vector3(0.26,0.05,0.26),"594633");cap.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    preview_ghost=Sprite3D.new();preview_ghost.render_priority=2;preview_ghost.billboard=BaseMaterial3D.BILLBOARD_ENABLED;preview_ghost.offset=Vector2(0,56);preview_ghost.modulate=Color(1.0,0.78,0.42,0.35);preview_ghost.pixel_size=MAP_PIXEL_SIZE;preview_ghost.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;preview_ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;preview_ghost.hide();add_child(preview_ghost)
    selection_ring=MeshInstance3D.new();var ring=TorusMesh.new();ring.inner_radius=0.36;ring.outer_radius=0.42;selection_ring.mesh=ring
    var ring_material=StandardMaterial3D.new();ring_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring_material.albedo_color=Color("91aaa3");selection_ring.material_override=ring_material;selection_ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(selection_ring)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = maxf(battle.size.x,battle.size.y)+1.8
    camera.position = Vector3((battle.size.x-1)*0.5+11.3137085,16,(battle.size.y-1)*0.5+11.3137085)
    add_child(camera)
    camera.look_at(Vector3((battle.size.x-1)*0.5,0,(battle.size.y-1)*0.5))
    camera.position -= camera.global_basis.x * 1.0
    camera.position -= camera.global_basis.y * 0.7
    camera.current = true
    route_mesh=MeshInstance3D.new();route_mesh.mesh=ImmediateMesh.new();add_child(route_mesh)
    route_arrows=MeshInstance3D.new();route_arrows.mesh=ImmediateMesh.new();add_child(route_arrows)
    var route_material=StandardMaterial3D.new();route_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;route_material.albedo_color=Color("e4c58a");route_material.cull_mode=BaseMaterial3D.CULL_DISABLED
    for node in [route_mesh,route_arrows]:node.material_override=route_material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visible=false
    build_border_props()
    var iso_characters={}
    if FileAccess.file_exists("res://assets/sprites/iso4/manifest.json"):
        var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/iso4/manifest.json"))
        if manifest is Dictionary:iso_characters=manifest.get("characters",{})
    for u in battle.units:
        var sprite = preload("res://view/lit_character.gd").new()
        var art="res://assets/characters/"+u.id+".png"
        if not ResourceLoader.exists(art):art="res://assets/sprites/"+u.role+".png"
        sprite.texture = load(art) if ResourceLoader.exists(art) else pixel_person(u.role,u.ally)
        sprite.set_meta("formal_art",ResourceLoader.exists(art))
        for direction in ["front","back","left","right"]:
            var path="res://assets/sprites/directional/"+u.role+"_"+direction+".png"
            if ResourceLoader.exists(path):direction_textures[u.id+":"+direction]=load(path)
        if iso_characters.has(u.role):
            var idle=iso_characters[u.role].get("idle",{});var loaded={}
            for direction in ["front_left","front_right","back_left","back_right"]:
                var file=idle.get(direction,"")
                if file is String and file.begins_with("assets/sprites/iso4/") and not file.contains("..") and ResourceLoader.exists("res://"+file):loaded[direction]=load("res://"+file)
            if loaded.size()==4:
                iso_roles[u.role]=true
                for direction in loaded:direction_textures[u.id+":"+direction]=loaded[direction]
        facing[u.id]=("back_right" if u.ally else "front_left") if iso_roles.has(u.role) else ("back" if u.ally else "front")
        last_positions[u.id]=u.pos
        sprite.pixel_size = MAP_PIXEL_SIZE if sprite.get_meta("formal_art") else 0.045
        sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED if sprite.get_meta("formal_art") else BaseMaterial3D.BILLBOARD_FIXED_Y
        if sprite.get_meta("formal_art"):sprite.offset=Vector2(0,56)
        sprite.shaded = true
        sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
        sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        add_child(sprite)
        figures.append(sprite)
        var meter=preload("res://view/unit_health.gd").new();meter.unit_index=figures.size()-1
        add_child(meter)
        badges.append(meter)

func pixel_person(role,ally):
    var image = Image.create(24,32,false,Image.FORMAT_RGBA8)
    image.fill(Color.TRANSPARENT)
    var coat = Color("587b8c")
    if role == "archer": coat = Color("66875e")
    elif role == "mage": coat = Color("a16d7c")
    elif not ally: coat = Color("ae7254")
    var dark = Color("493e3d")
    image.fill_rect(Rect2i(7,27,4,4),dark)
    image.fill_rect(Rect2i(13,27,4,4),dark)
    image.fill_rect(Rect2i(6,14,12,14),coat.darkened(0.25))
    image.fill_rect(Rect2i(7,14,8,12),coat)
    image.fill_rect(Rect2i(8,6,9,9),Color("dba77b"))
    image.fill_rect(Rect2i(8,5,9,4),Color("77523c"))
    image.fill_rect(Rect2i(8,5,3,7),Color("77523c"))
    image.fill_rect(Rect2i(13,10,2,2),dark)
    image.fill_rect(Rect2i(4,16,3,7),coat)
    image.fill_rect(Rect2i(17,16,3,7),coat)
    image.fill_rect(Rect2i(7,23,11,2),Color("b99b60"))
    if role == "knight" or role == "brute":
        image.fill_rect(Rect2i(8,4,10,4),Color("c2c7bd"))
        image.fill_rect(Rect2i(18,11,2,15),Color("e6dcc3"))
        image.fill_rect(Rect2i(16,23,6,2),Color("a9905a"))
        image.fill_rect(Rect2i(3,17,5,9),Color("9c7655"))
    elif role == "mage":
        image.fill_rect(Rect2i(7,3,11,4),coat)
        image.fill_rect(Rect2i(9,0,6,4),coat)
        image.fill_rect(Rect2i(19,9,2,22),Color("9a754c"))
        image.fill_rect(Rect2i(18,7,4,4),Color("ffd49b"))
    else:
        image.fill_rect(Rect2i(19,12,2,13),Color("bfa071"))
        image.fill_rect(Rect2i(17,10,2,4),Color("bfa071"))
        image.fill_rect(Rect2i(17,24,2,4),Color("bfa071"))
    return ImageTexture.create_from_image(image)

func build_hud():
    hud=Hud.new();hud.game=self;add_child(hud)
    cutin=preload("res://ui/battle_cutin.gd").new();add_child(cutin)
    motion=preload("res://view/unit_motion.gd").new();motion.game=self;add_child(motion);motion.last_step=battle.step
    heal_feedback=preload("res://view/heal_feedback.gd").new();heal_feedback.game=self;add_child(heal_feedback);heal_feedback.last_step=battle.step

func select_mode(value):
    if presentation_active() or (hud and hud.blocks_input()):return
    mode = value
    if hud:hud.action_menu_open=false
    refresh()

# Presentation-only proposal. No command is sent until explicit confirmation.
func stage_move(cell):
    if targeting_locked() or selected<0:return false
    pending_move={};update_move_preview(cell)
    if preview_path.is_empty():return false
    pending_move={"unit":selected,"actor_id":battle.units[selected].id,"step":battle.step,"cell":cell,"path":preview_path.duplicate(true),"state":proposal_state(),"logic_id":battle.get_instance_id(),"mode":mode}
    hud.refresh();return true

func confirm_move():
    battle=session.logic
    if pending_move.is_empty():return false
    if targeting_locked():clear_move_preview();return false
    var proposal=pending_move.duplicate(true)
    var valid=mode==proposal.mode and mode=="move" and proposal_state()==proposal.state and battle.get_instance_id()==proposal.logic_id and selected==proposal.unit and battle.step==proposal.step and battle.units[selected].id==proposal.actor_id and battle.path_to(selected,proposal.cell)==proposal.path
    clear_move_preview()
    if not valid:hud.refresh();return false
    var accepted=session.submit({"kind":"move","unit":selected,"actor_id":proposal.actor_id,"x":proposal.cell.x,"y":proposal.cell.y})
    battle=session.logic;refresh();return accepted

func proposal_state():return battle.content_hash+":"+battle.rules_hash+":"+battle.state_hash()

func targeting_locked():
    return session.pending or session.failed or presentation_active() or hud.blocks_input()

func target_command(target):
    var command={"unit":selected,"target":target,"kind":mode}
    if mode.begins_with("ability:"):command.kind="ability";command.ability=mode.trim_prefix("ability:")
    if mode.begins_with("item:"):command.kind="item";command.consumable=mode.trim_prefix("item:")
    return command

func stage_target(cell):
    pending_target={}
    update_target_preview(cell)
    if targeting_locked() or target_preview.is_empty() or selected<0:return false
    var target=target_preview_index
    pending_target={"unit":selected,"actor_id":battle.units[selected].id,"mode":mode,"step":battle.step,"state":proposal_state(),"logic_id":battle.get_instance_id(),"target":target,"target_id":battle.units[target].id,"cell":cell,"command":target_command(target)}
    hud.refresh();return true

func confirm_proposal():
    battle=session.logic
    if not pending_move.is_empty():return confirm_move()
    if pending_target.is_empty():return false
    var proposal=pending_target.duplicate(true)
    var valid=not targeting_locked() and selected==proposal.unit and mode==proposal.mode and battle.step==proposal.step and proposal_state()==proposal.state and battle.get_instance_id()==proposal.logic_id
    if valid:
        valid=battle.units[selected].id==proposal.actor_id and battle.at(proposal.cell)==proposal.target and battle.units[proposal.target].id==proposal.target_id and battle.preview_action(proposal.command).get("legal",false)
    clear_move_preview() # Consume before submit, including rejected/pending commands.
    if not valid:hud.refresh();return false
    var accepted=session.submit(proposal.command)
    battle=session.logic;hud.action_menu_open=true;refresh();return accepted

func wait_selected():
    if selected<0 or presentation_active() or hud.blocks_input():return false
    clear_move_preview()
    var accepted=session.submit({"kind":"wait","unit":selected,"actor_id":battle.units[selected].id})
    battle=session.logic;hud.action_menu_open=true;refresh();return accepted

func finish_turn():
    if presentation_active() or (hud and hud.blocks_input()):return
    session.submit({"kind":"end_turn"})
    battle=session.logic
    refresh()

func restart():
    if session.online:
        session.status="Online battle restart requires restarting authority. R only resets offline play."
        return
    App.new_game(session.logic.content)
    session=App.session
    battle=session.logic
    selected = 0
    mode = "move"
    refresh()

func refresh():
    if route_mesh:clear_move_preview()
    target_preview={};target_preview_index=-1
    if cutin and battle.step!=cutin.last_seen_step:cutin.finish()
    if motion:motion.consume(battle.step,battle.events)
    if not battle.usable(selected):
        selected = -1
        for i in range(battle.units.size()):
            if battle.usable(i):
                selected = i
                break
    var possible = battle.reachable(selected) if selected >= 0 else {}
    preview_reachable=possible
    selection_ring.visible=selected>=0
    if selected>=0:selection_ring.position=Vector3(battle.units[selected].x,0.04,battle.units[selected].y)
    for pos in tiles:
        tiles[pos].node.material_override.albedo_color=tiles[pos].color
        tiles[pos].overlay.visible=false # Generated range layer owns fill and border once.
    for i in range(battle.units.size()):
        var u = battle.units[i]
        figures[i].visible = u.hp > 0
        badges[i].visible = u.hp > 0
        if last_positions.has(u.id) and last_positions[u.id]!=u.pos:
            facing[u.id]=projected_facing(last_positions[u.id],u.pos,iso_roles.has(u.role))
        last_positions[u.id]=u.pos
        for event in battle.events:
            if event.get("kind")=="attack" and event.get("actor")==u.id:
                for target in battle.units:
                    if target.id==event.target:facing[u.id]=projected_facing(u.pos,target.pos,iso_roles.has(u.role))
        if not motion.motions.has(u.id):figures[i].texture=directional_idle_texture(i,facing.get(u.id,"front"))
        if not motion.motions.has(u.id):figures[i].position = Vector3(u.pos.x,figure_height(i),u.pos.y)
        badges[i].position = badge_position(i)
        badges[i].update_health(u.hp,u.max_hp,u.ally,i==selected)
    if hud:hud.refresh()
    if cutin and not motion.active():cutin.consume(battle.step,battle.events,battle.units,battle.content)
    if heal_feedback:heal_feedback.consume(battle.step,battle.events)

func _unhandled_input(event):
    if event is InputEventKey and event.pressed and not event.echo:
        if presentation_active() and event.physical_keycode in [KEY_SPACE,KEY_ENTER,KEY_ESCAPE]:skip_presentation();get_viewport().set_input_as_handled();return
        if event.physical_keycode==KEY_ESCAPE:
            if not hud.blocks_input() and not hud.action_menu_open:hud.cancel_targeting()
            else:hud.toggle_pause()
            return
        if hud.story_panel.visible and event.physical_keycode in [KEY_SPACE,KEY_ENTER]:hud.advance(false);return
    if targeting_locked():
        clear_move_preview();return
    if event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_A:
        if hud.activate_focused_action():get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.physical_keycode:
            KEY_1,KEY_M: select_mode("move")
            KEY_2,KEY_A: select_mode("attack")
            KEY_3: hud.choose_action("skill")
            KEY_S: hud.choose_action("skill")
            KEY_4,KEY_I: hud.choose_action("item")
            KEY_5,KEY_W: wait_selected()
            KEY_ENTER:
                if not pending_move.is_empty() or not pending_target.is_empty():confirm_proposal()
                elif not hud.activate_focused_action():hud.open_action_menu()
                get_viewport().set_input_as_handled()
            KEY_SPACE: hud.request_end_turn()
            KEY_R: restart()
    if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
        hud.cancel_targeting();return
    if event is InputEventMouseMotion:
        if mode=="move" and not hud.action_menu_open and pending_move.is_empty():update_move_preview(mouse_cell(event.position))
        elif pending_target.is_empty():update_target_preview(mouse_cell(event.position))
        return
    # Touch targets are handled once here; its emulated mouse still serves GUI controls.
    var pointer_tap=(event is InputEventScreenTouch and event.pressed and event.index==0) or (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and event.device!=-1)
    if pointer_tap:
        var cell=mouse_cell(event.position)
        if cell.x<0:
            clear_move_preview();hud.refresh();return
        var target = battle.at(cell)
        if target >= 0 and battle.units[target].controller=="player" and (mode=="move" or (mode=="attack" and selected>=0 and battle.units[target].faction==battle.units[selected].faction)):
            selected = target
            hud.action_menu_open=true
            clear_move_preview()
        elif mode == "move":
            if hud.action_menu_open:return
            if not pending_move.is_empty() and pending_move.cell==cell:confirm_move()
            else:stage_move(cell)
            hud.refresh();return
        else:
            if hud.action_menu_open:return
            if not pending_target.is_empty() and pending_target.cell==cell:confirm_proposal()
            else:stage_target(cell)
            hud.refresh();return
        battle=session.logic
        refresh()

func _process(delta):
    battle=session.logic
    var proposal=pending_move if not pending_move.is_empty() else pending_target
    if not proposal.is_empty() and (targeting_locked() or selected!=proposal.unit or mode!=proposal.mode or battle.step!=proposal.step or battle.get_instance_id()!=proposal.logic_id):clear_move_preview()
    if battle.step!=last_step:
        if hud:hud.action_menu_open=true
        last_step=battle.step
        refresh()
    if hud:hud.refresh_story();hud.refresh()

func _exit_tree():
    pass # App owns session across menus; explicit leave closes transport.

func request_exit():hud.confirm_leave(true)

func projected_facing(from_cell,to_cell,diagonal=false):
    var start=camera.unproject_position(Vector3(from_cell.x,0,from_cell.y))
    var finish=camera.unproject_position(Vector3(to_cell.x,0,to_cell.y))
    var delta=finish-start
    if diagonal:return ("front_right" if delta.x>=0 else "front_left") if delta.y>=0 else ("back_right" if delta.x>=0 else "back_left")
    if absf(delta.x)>absf(delta.y):return "right" if delta.x>0 else "left"
    return "front" if delta.y>0 else "back"

func presentation_active():return (motion and motion.active()) or (cutin and cutin.active)
func motion_finished():
    if hud:hud.action_menu_open=true
    if cutin:cutin.consume(battle.step,battle.events,battle.units,battle.content)
func skip_presentation():
    if heal_feedback:heal_feedback.clear()
    if motion:motion.finish()
    if cutin:cutin.finish()

func mouse_cell(screen):
    if scene_view and not scene_view.accepts_point(screen):return Vector2i(-1,-1)
    var origin=camera.project_ray_origin(screen);var direction=camera.project_ray_normal(screen)
    if absf(direction.y)<0.001:return Vector2i(-1,-1)
    var hit=origin+direction*(-origin.y/direction.y)
    return Vector2i(floori(hit.x+0.5),floori(hit.z+0.5))
func clear_move_preview():
    pending_move={};pending_target={};target_preview={};target_preview_index=-1
    preview_path=[];preview_reason="";preview_cell=Vector2i(-1,-1)
    if preview_ghost:preview_ghost.hide()
    route_mesh.mesh.clear_surfaces();route_arrows.mesh.clear_surfaces()
func update_move_preview(cell):
    if cell==preview_cell:return
    clear_move_preview();preview_cell=cell
    if selected<0 or mode!="move" or presentation_active() or hud.blocks_input():return
    preview_path=battle.path_to(selected,cell)
    if preview_path.is_empty():preview_reason="此格不可达 · 选择范围内的空格";return
    preview_ghost.texture=figures[selected].texture;preview_ghost.position=Vector3(cell.x,figures[selected].position.y,cell.y);preview_ghost.show()
    var line=route_mesh.mesh;var arrows=route_arrows.mesh
    line.surface_begin(Mesh.PRIMITIVE_LINES);arrows.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(preview_path.size()-1):
        var a=preview_path[i];var b=preview_path[i+1]
        var start=Vector3(a.x,0.06,a.y);var finish=Vector3(b.x,0.06,b.y)
        line.surface_add_vertex(start);line.surface_add_vertex(finish)
        var direction=(finish-start).normalized();var side=Vector3(-direction.z,0,direction.x)*0.10
        var tip=finish-direction*0.12;var back=tip-direction*0.22
        arrows.surface_add_vertex(tip);arrows.surface_add_vertex(back+side);arrows.surface_add_vertex(back-side)
    var end=preview_path[-1];var center=Vector3(end.x,0.06,end.y)
    for i in range(4):
        var corners=[Vector3(-0.25,0,-0.25),Vector3(0.25,0,-0.25),Vector3(0.25,0,0.25),Vector3(-0.25,0,0.25)]
        line.surface_add_vertex(center+corners[i]);line.surface_add_vertex(center+corners[(i+1)%4])
    line.surface_end();arrows.surface_end()

func update_target_preview(cell):
    target_preview={};target_preview_index=-1
    if selected<0 or mode=="move" or presentation_active() or hud.blocks_input():return
    var target=battle.at(cell)
    if target<0:return
    var command=target_command(target)
    var result=battle.preview_action(command)
    if result.get("legal",false):target_preview=result;target_preview_index=target

func build_border_props():
    var path="res://assets/environment/props_v3/manifest.json"
    if not FileAccess.file_exists(path):return
    var definitions=JSON.parse_string(FileAccess.get_file_as_string(path)).props
    var foliage_path="res://assets/environment/foliage_v4/manifest.json"
    var foliage={}
    if FileAccess.file_exists(foliage_path):foliage=JSON.parse_string(FileAccess.get_file_as_string(foliage_path)).get("props",{})
    var placements=[["tree",Vector2(3.5,-1.35)],["tree",Vector2(battle.size.x-3,-1.5)],["tree",Vector2(-1.5,1.5)],["shrub",Vector2(3,-0.9)],["shrub",Vector2(battle.size.x+0.15,1.4)],["shrub",Vector2(battle.size.x-1,battle.size.y+0.05)],["reeds_rocks",Vector2(-0.8,3.0)],["reeds_rocks",Vector2(battle.size.x+0.2,4.0)],["supplies",Vector2(-1.8,7.55)],["lantern",Vector2(-0.2,7.8)]]
    for x in range(-4,battle.size.x+5):
        placements.append(["tree",Vector2(x+0.5*sin(x*1.7),-3.3-0.6*((x+8)%3))])
        if x<1 or x>battle.size.x-3:placements.append(["tree",Vector2(x+0.5*cos(x*1.3),battle.size.y+2.4+0.4*sin(x))])
    for z in range(-1,battle.size.y+2,2):
        var river_row=z>=0 and z<battle.size.y and battle.content.terrain[z].replace("W","").replace("B","").is_empty()
        if not river_row:
            placements.append(["tree",Vector2(-3.0-0.3*sin(z),z)]);placements.append(["tree",Vector2(battle.size.x+2.0+0.3*cos(z),z)])
    placements.append(["tree",Vector2(-2.5,6.3)]);placements.append(["tree",Vector2(battle.size.x+2,6.3)])
    for x in range(-3,battle.size.x+3):
        for z in [-0.8,battle.size.y-0.15]:
            placements.append(["shrub",Vector2(x+0.2*sin(x*1.4),z)])
            if x%2==0:placements.append(["reeds_rocks",Vector2(x,battle.size.y-4.45)])
    if battle.content.id=="amber_bridge_reference":
        for z in range(battle.size.y):
            for x in range(battle.size.x):
                if battle.content.terrain[z][x]=="X":placements.append(["shrub",Vector2(x,z)])
    for placement in placements:
        var cell=placement[1]
        var inside=cell.x>=-0.5 and cell.x<battle.size.x-0.5 and cell.y>=-0.5 and cell.y<battle.size.y-0.5
        if inside and (placement[0] not in ["tree","shrub"] or battle.content.terrain[roundi(cell.y)][roundi(cell.x)]!="X"):continue
        var species=placement[0]
        if not foliage.is_empty():
            if species=="tree":
                var pick=posmod(roundi(cell.x*7+cell.y*3),4)
                species=["oak","birch","conifer","birch"][pick]
                if cell.y>=2 and cell.y<=6.5:species="willow"
                # Keep large crowns outside the tactical area, rather than hiding units behind cards.
                if cell.x<0:cell.x=minf(cell.x,-2.4)
                elif cell.x>=battle.size.x:cell.x=maxf(cell.x,battle.size.x+1.8)
                if cell.y<0:cell.y=minf(cell.y,-2.4)
                elif cell.y>=battle.size.y:cell.y=maxf(cell.y,battle.size.y+1.8)
            elif species=="shrub":species="shrub_round" if inside or posmod(roundi(cell.x*3+cell.y),2)==0 else "shrub_tall"
        var d=foliage.get(species,definitions[placement[0]]);var sprite=Sprite3D.new();sprite.texture=load("res://"+d.path);sprite.pixel_size=d.pixel_size
        sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.shaded=true;sprite.modulate=Color.WHITE;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
        sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=0.5;sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        var base_y=water_level+0.08 if placement[0]=="reeds_rocks" else (-0.13 if placement[0]=="tree" else -0.03)
        if placement[0]=="tree" and (cell.x<-2 or cell.x>battle.size.x+1 or cell.y<-2 or cell.y>battle.size.y+1):
            var variation=0.95+0.12*sin(cell.x*2.3+cell.y);sprite.pixel_size*=variation
            sprite.modulate=Color(0.65,0.76,0.72)
        sprite.position=Vector3(cell.x,base_y+(d.pivot_px[1]-128)*sprite.pixel_size,cell.y);sprite.set_meta("decorative_kind",placement[0]);sprite.set_meta("species",species);sprite.set_meta("ground_cell",cell);sprite.set_meta("alpha_bbox",d.get("alpha_bbox_px",[0,0,256,256]));add_child(sprite);decorative_props.append(sprite)

func landscape_box(pos,size,color):
    var node=box(pos,size,color)
    node.material_override.albedo_color=Color(0.55,0.64,0.58)
    return node

func figure_height(index):
    return 0.0 if figures[index].get_meta("formal_art") else 0.72
func figure_pixel_position(index,pixel):
    var figure=figures[index]
    if figure.get_meta("formal_art"):
        return figure.position+camera.global_basis.x*(pixel.x-48)*figure.pixel_size+camera.global_basis.y*(120-pixel.y)*figure.pixel_size
    return figure.position+camera.global_basis.x*(pixel.x-12)*figure.pixel_size+Vector3.UP*(16-pixel.y)*figure.pixel_size
func badge_position(index):
    return figure_pixel_position(index,Vector2(48,0))+camera.global_basis.y*0.15 if figures[index].get_meta("formal_art") else figures[index].position+Vector3.UP*0.9
func badge_height(index):
    return badge_position(index).y
func set_character_scale(value):
    character_scale=clampf(value,0.5,1.5)
    for i in range(figures.size()):
        if figures[i].get_meta("formal_art"):figures[i].pixel_size=MAP_PIXEL_SIZE*character_scale
        figures[i].position.y=figure_height(i)
        badges[i].position=badge_position(i)
    preview_ghost.pixel_size=MAP_PIXEL_SIZE*character_scale
    if preview_ghost.visible and selected>=0:preview_ghost.position.y=figure_height(selected)

# Shared neutral source for stationary entry and static movement.
# Animation is unit-scoped; unrelated Mod units keep their original art.
func directional_idle_texture(index,direction):
    var unit=battle.units[index]
    var fallback=direction_textures.get(unit.id+":"+direction,figures[index].texture)
    var idle=get_node_or_null("MapIdle")
    return idle.library.sample("map",unit.role+":"+direction,0.0,fallback,true,unit.id) if idle else fallback
