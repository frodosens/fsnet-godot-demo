extends Node3D
const Session = preload("res://logic/session.gd")
var session
const Hud=preload("res://ui/battle_hud.gd")
var hud
var cutin
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

func material(color):
    var m = StandardMaterial3D.new()
    m.albedo_color = Color(color)
    m.roughness = 0.9
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
    settings.background_color = Color("c7ac87")
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color("e9d9bb")
    settings.ambient_light_energy = 0.35
    environment.environment = settings
    add_child(environment)
    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48,-35,0)
    sun.light_color = Color("ffd58b")
    sun.light_energy = 0.85
    sun.shadow_enabled = true
    add_child(sun)
    for z in range(battle.size.y):
        for x in range(battle.size.x):
            var pos = Vector2i(x,z)
            var water = battle.content.terrain[z][x]=="W"
            var bridge = battle.content.terrain[z][x]=="B"
            var color = "547f89" if water else ("bdab8b" if bridge else ("8e9d64" if (x+z)%2 else "9eaa70"))
            var tile = box(Vector3(x,-0.18 if not water else -0.38,z),Vector3(0.98,0.3 if not water else 0.12,0.98),color)
            tiles[pos] = {"node":tile,"color":color}
    # Bridge rails follow the data map; X cells are actual blocked obstacles.
    for z in range(battle.size.y):
        for x in range(battle.size.x):
            if battle.content.terrain[z][x]=="X":box(Vector3(x,0.22,z),Vector3(0.8,0.6,0.8),"84775f")
            if battle.content.terrain[z][x]=="B":
                for side in [-1,1]:
                    if x+side>=0 and x+side<battle.size.x and battle.content.terrain[z][x+side]=="W":
                        box(Vector3(x+side*0.47,0.13,z),Vector3(0.12,0.5,0.8),"a08e77")
    # Small original low-poly roadside inn: no imported models or textures.
    box(Vector3(-1.1,0.6,6.7),Vector3(1.5,1.4,1.0),"d9b986")
    box(Vector3(-1.1,1.4,6.7),Vector3(1.8,0.3,1.3),"9d6749")
    box(Vector3(-1.1,0.3,7.22),Vector3(0.38,0.8,0.04),"694d3b")
    for x in [-1.52,-0.65]: box(Vector3(x,0.85,7.23),Vector3(0.26,0.28,0.05),"ffdc88")
    for p in [Vector3(2,0,7),Vector3(7,0,0)]:
        box(p+Vector3(0,0.5,0),Vector3(0.08,1,0.08),"594633")
        var lamp = OmniLight3D.new()
        lamp.position = p+Vector3(0,1,0)
        lamp.light_color = Color("ffb954")
        lamp.light_energy = 0.8
        lamp.omni_range = 3
        lamp.shadow_enabled = true
        add_child(lamp)
        box(p+Vector3(0,1,0),Vector3(0.2,0.24,0.2),"ffcf78")
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = maxf(battle.size.x,battle.size.y)+4.4
    camera.position = Vector3(13,16,17)
    add_child(camera)
    camera.look_at(Vector3((battle.size.x-1)*0.5,0,(battle.size.y-1)*0.5))
    camera.position -= camera.global_basis.x * 1.0
    camera.position -= camera.global_basis.y * 1.0
    camera.current = true
    for u in battle.units:
        var sprite = Sprite3D.new()
        var art="res://assets/characters/"+u.id+".png"
        if not ResourceLoader.exists(art):art="res://assets/sprites/"+u.role+".png"
        sprite.texture = load(art) if ResourceLoader.exists(art) else pixel_person(u.role,u.ally)
        sprite.set_meta("formal_art",ResourceLoader.exists(art))
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

func select_mode(value):
    if (cutin and cutin.active) or (hud and hud.blocks_input()):return
    mode = value
    refresh()

func finish_turn():
    if (cutin and cutin.active) or (hud and hud.blocks_input()):return
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
    if not battle.usable(selected):
        selected = -1
        for i in range(battle.units.size()):
            if battle.usable(i):
                selected = i
                break
    var possible = battle.reachable(selected) if selected >= 0 else {}
    for pos in tiles:
        var color = Color(tiles[pos].color)
        if selected >= 0 and battle.units[selected].pos == pos: color = Color("e7c36c")
        elif selected >= 0 and mode == "move" and not battle.units[selected].moved and possible.has(pos): color = color.lerp(Color("f8d991"),0.4)
        tiles[pos].node.material_override.albedo_color = color
    for i in range(battle.units.size()):
        var u = battle.units[i]
        figures[i].visible = u.hp > 0
        badges[i].visible = u.hp > 0
        figures[i].position = Vector3(u.pos.x,0.63 if figures[i].get_meta("formal_art") else 0.72,u.pos.y)
        badges[i].position = Vector3(u.pos.x,1.62,u.pos.y)
        badges[i].text = "%s  %d/%d" % [u.name,u.hp,u.max_hp]
        badges[i].modulate = Color("fff0c9") if u.ally else Color("ffd2b4")
    if hud:hud.refresh()
    if cutin:cutin.consume(battle.step,battle.events)

func _unhandled_input(event):
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode==KEY_ESCAPE:hud.toggle_pause();return
        if hud.story_panel.visible and event.physical_keycode in [KEY_SPACE,KEY_ENTER]:hud.advance(false);return
    if cutin.active or hud.blocks_input():return
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
        if target >= 0 and battle.units[target].ally and not (mode == "skill" and target == selected):
            selected = target
        elif mode == "move":
            session.submit({"kind":"move","unit":selected,"x":cell.x,"y":cell.y})
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
