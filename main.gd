extends Node3D
const Session = preload("res://logic/session.gd")
var session
const Hud=preload("res://ui/battle_hud.gd")
var hud
var cutin
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
var selection_ring

func material(color):
    var m = StandardMaterial3D.new()
    var kinds={"87775b":"dirt","59624b":"grass","626a52":"grass","596d76":"water","85847a":"stone_paving","a08e77":"stone_wall","84775f":"stone_wall","8b887b":"plaster","73594d":"roof","694d3b":"wood","594633":"wood"}
    var path="res://assets/environment/v2/"+str(kinds.get(color,""))+".png"
    var textured=ResourceLoader.exists(path)
    m.albedo_color=Color.WHITE if textured else Color(color)
    if textured:
        m.albedo_texture=load(path);m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
        m.uv1_triplanar=true;m.uv1_world_triplanar=true;m.uv1_triplanar_sharpness=8.0
    m.roughness=1.0;m.metallic_specular=0.0
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
    build_hud()
    refresh()
    print("PROTOTYPE_READY shared_lua=true units=6 tiles=80 renderer=" + RenderingServer.get_video_adapter_name())
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
        if figures.size() != 6 or tiles.size() != 80:
            get_tree().quit(1)
        else:
            print("SCENE_SMOKE_OK (scene construction only; no visual assertion)")
            get_tree().quit(0)

func build_world():
    var environment = WorldEnvironment.new()
    var settings = Environment.new()
    settings.background_mode = Environment.BG_COLOR
    settings.background_color = Color("202b29")
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color("d6d9ce")
    settings.ambient_light_energy = 0.35
    environment.environment = settings
    add_child(environment)
    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48,-35,0)
    sun.light_color = Color("e8dfcf")
    sun.light_energy = 0.65
    sun.shadow_enabled = true
    add_child(sun)
    for z in range(battle.size.y):
        for x in range(battle.size.x):
            var pos = Vector2i(x,z)
            var water = battle.content.terrain[z][x]=="W"
            var bridge = battle.content.terrain[z][x]=="B"
            var dirt=battle.content.terrain[z][x]=="D"
            var color = "596d76" if water else ("85847a" if bridge else ("87775b" if dirt else ("59624b" if (x+z)%2 else "626a52")))
            var tile = box(Vector3(x,-0.15 if not water else -0.72,z),Vector3(0.98,0.3 if not water else 0.12,0.98),color)
            var overlay=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(0.93,0.93);overlay.mesh=plane
            var highlight=StandardMaterial3D.new();highlight.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;highlight.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;highlight.albedo_color=Color(0.65,0.74,0.67,0.16)
            overlay.material_override=highlight;overlay.position=Vector3(x,0.012,z);overlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;overlay.visible=false;add_child(overlay)
            tiles[pos] = {"node":tile,"color":tile.material_override.albedo_color,"overlay":overlay}
    # Bridge rails follow the data map; X cells are actual blocked obstacles.
    for z in range(battle.size.y):
        for x in range(battle.size.x):
            if battle.content.terrain[z][x]=="X":box(Vector3(x,0.22,z),Vector3(0.8,0.6,0.8),"84775f")
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
                        var bottom=-0.72+0.44*sin(t*PI)
                        var height=-0.15-bottom
                        box(Vector3(x+side*0.47,bottom+height*0.5,start-0.5+(piece+0.5)/8.0),Vector3(0.16,height,0.13),"a08e77")
                start=-1
    # Small original roadside inn geometry using the authored environment albedos.
    box(Vector3(-1.1,0.6,6.7),Vector3(1.5,1.4,1.0),"8b887b")
    var roof=MeshInstance3D.new();var roof_shape=PrismMesh.new();roof_shape.size=Vector3(1.9,0.8,1.4)
    roof.mesh=roof_shape;roof.material_override=material("73594d");roof.position=Vector3(-1.1,1.7,6.7);add_child(roof)
    for x in [-1.8,-0.4]:box(Vector3(x,0.6,7.23),Vector3(0.09,1.4,0.07),"694d3b")
    box(Vector3(-1.1,1.22,7.23),Vector3(1.5,0.09,0.07),"694d3b")
    box(Vector3(-1.1,0.3,7.22),Vector3(0.38,0.8,0.04),"694d3b")
    for x in [-1.52,-0.65]: box(Vector3(x,0.85,7.23),Vector3(0.26,0.28,0.05),"d7b87d")
    for p in [Vector3(2,0,7),Vector3(7,0,0)]:
        box(p+Vector3(0,0.5,0),Vector3(0.08,1,0.08),"594633")
        var lamp = OmniLight3D.new()
        lamp.position = p+Vector3(0,1,0)
        lamp.light_color = Color("ceab7c")
        lamp.light_energy = 0.30
        lamp.omni_range = 3
        lamp.shadow_enabled = true
        add_child(lamp)
        box(p+Vector3(0,1,0),Vector3(0.2,0.24,0.2),"ce9a57")
    selection_ring=MeshInstance3D.new();var ring=TorusMesh.new();ring.inner_radius=0.36;ring.outer_radius=0.42;selection_ring.mesh=ring
    var ring_material=StandardMaterial3D.new();ring_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ring_material.albedo_color=Color("91aaa3");selection_ring.material_override=ring_material;selection_ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(selection_ring)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = maxf(battle.size.x,battle.size.y)+4.4
    camera.position = Vector3((battle.size.x-1)*0.5+8.5,16,(battle.size.y-1)*0.5+13.5)
    add_child(camera)
    camera.look_at(Vector3((battle.size.x-1)*0.5,0,(battle.size.y-1)*0.5))
    camera.position -= camera.global_basis.x * 1.0
    camera.position -= camera.global_basis.y * 1.0
    camera.current = true
    var iso_characters={}
    if FileAccess.file_exists("res://assets/sprites/iso4/manifest.json"):
        var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/iso4/manifest.json"))
        if manifest is Dictionary:iso_characters=manifest.get("characters",{})
    for u in battle.units:
        var sprite = Sprite3D.new()
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
        sprite.pixel_size = 0.01125 if sprite.get_meta("formal_art") else 0.045
        sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
        sprite.shaded = true
        sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
        sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        add_child(sprite)
        figures.append(sprite)
        var label = Label3D.new()
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.font_size = 30
        label.pixel_size = 0.007
        label.outline_size = 8
        add_child(label)
        badges.append(label)

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

func select_mode(value):
    if presentation_active() or (hud and hud.blocks_input()):return
    mode = value
    refresh()

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
    if cutin and battle.step!=cutin.last_seen_step:cutin.finish()
    if motion:motion.consume(battle.step,battle.events)
    if not battle.usable(selected):
        selected = -1
        for i in range(battle.units.size()):
            if battle.usable(i):
                selected = i
                break
    var possible = battle.reachable(selected) if selected >= 0 else {}
    selection_ring.visible=selected>=0
    if selected>=0:selection_ring.position=Vector3(battle.units[selected].x,0.04,battle.units[selected].y)
    for pos in tiles:
        tiles[pos].node.material_override.albedo_color=tiles[pos].color
        tiles[pos].overlay.visible=selected>=0 and mode=="move" and not battle.units[selected].moved and possible.has(pos)
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
        var texture_key=u.id+":"+facing.get(u.id,"front")
        if direction_textures.has(texture_key) and not motion.motions.has(u.id):figures[i].texture=direction_textures[texture_key]
        if not motion.motions.has(u.id):figures[i].position = Vector3(u.pos.x,0.63 if figures[i].get_meta("formal_art") else 0.72,u.pos.y)
        badges[i].position = Vector3(u.pos.x,1.62,u.pos.y)
        badges[i].text = "%s  %d/%d" % [u.name,u.hp,u.max_hp]
        badges[i].modulate = Color("fff0c9") if u.ally else Color("ffd2b4")
    if hud:hud.refresh()
    if cutin and not motion.active():cutin.consume(battle.step,battle.events)

func _unhandled_input(event):
    if event is InputEventKey and event.pressed and not event.echo:
        if presentation_active() and event.physical_keycode in [KEY_SPACE,KEY_ENTER,KEY_ESCAPE]:skip_presentation();get_viewport().set_input_as_handled();return
        if event.physical_keycode==KEY_ESCAPE:hud.toggle_pause();return
        if hud.story_panel.visible and event.physical_keycode in [KEY_SPACE,KEY_ENTER]:hud.advance(false);return
    if presentation_active() or hud.blocks_input():return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.physical_keycode:
            KEY_1: select_mode("move")
            KEY_2: select_mode("attack")
            KEY_3: select_mode("skill")
            KEY_SPACE: finish_turn()
            KEY_R: restart()
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var origin = camera.project_ray_origin(event.position)
        var direction = camera.project_ray_normal(event.position)
        if absf(direction.y) < 0.001: return
        var hit = origin + direction * (-origin.y/direction.y)
        var cell = Vector2i(floori(hit.x+0.5),floori(hit.z+0.5))
        var target = battle.at(cell)
        if target >= 0 and battle.units[target].controller=="player" and (mode=="move" or (mode=="attack" and selected>=0 and battle.units[target].faction==battle.units[selected].faction)):
            selected = target
        elif mode == "move":
            session.submit({"kind":"move","unit":selected,"x":cell.x,"y":cell.y})
        elif mode.begins_with("item:"):
            session.submit({"kind":"item","consumable":mode.trim_prefix("item:"),"unit":selected,"target":target})
        elif mode.begins_with("ability:"):
            session.submit({"kind":"ability","ability":mode.trim_prefix("ability:"),"unit":selected,"target":target})
        else:
            session.submit({"kind":"skill" if mode=="skill" else "attack","unit":selected,"target":target})
        battle=session.logic
        refresh()

func _process(delta):
    battle=session.logic
    if battle.step!=last_step:
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
    if cutin:cutin.consume(battle.step,battle.events)
func skip_presentation():
    if motion:motion.finish()
    if cutin:cutin.finish()
