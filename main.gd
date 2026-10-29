extends Node3D
var session
const Architecture=preload("res://view/architecture.gd")
const Hud=preload("res://ui/battle_hud.gd")
var hud
var cutin
var event_sequence
var heal_feedback
var map_magic
var generic_attack_feedback
var motion
var battle
var last_step = -1
var network_label: Label
var selected = 0
var selection_initialized=false
var selection_seen_id=""
var selection_seen_round=-1
var selection_pending_move=false
var selection_pending_focus=false
var mode = "move"
var camera: Camera3D
var tiles = {}
var board
var board_camera
var command_gate
var figures = []
var badges = []
var status: Label
var detail: Label
var message: Label
var buttons = []
var facing={}
# Separate movement-only opt-in; does not replace Neri idle profile.
var hero_refresh_libraries={
    "rodd":preload("res://view/map_sequence.gd").new("res://assets/sprites/iso4/rodd_seedance_mini_v1/runtime_manifest.json"),
    "mara":preload("res://view/map_sequence.gd").new("res://assets/sprites/iso4/mara_seedance_mini_v2/runtime_manifest.json"),
    "finn":preload("res://view/map_sequence.gd").new("res://assets/sprites/iso4/finn_seedance_mini_v2/runtime_manifest.json"),
    "neri":preload("res://view/map_sequence.gd").new("res://assets/sprites/iso4/neri_seedance_mini_v2/runtime_manifest.json")}
var elsbet_motion_library=preload("res://view/map_sequence.gd").new("res://assets/sprites/iso4/elsbet_seedance_mini_v2/runtime_manifest.json")
var neri_motion_library=preload("res://view/map_sequence.gd").new("res://assets/animations/neri_motion_trial.json")
var vera_motion_enabled=true # Candidate may be disabled locally; missing art falls back to canonical static.
var vera_motion_library=preload("res://view/map_sequence.gd").new("res://assets/animations/vera_chapter_motion.json")
var adela_motion_library=preload("res://view/map_sequence.gd").new("res://assets/animations/adela_motion_trial.json")
var last_positions={}
var direction_textures={}
var iso_roles={}
var target_preview={}
var target_preview_index=-1
var target_hover_cell=Vector2i(-1,-1)
var preview_reason=""
var preview_reachable={}
var pending_move={}
var pending_target={}
var queued_confirmation={}
var preview_path=[]
var preview_cell=Vector2i(-1,-1)
var route_mesh
var decorative_props=[]
var water_level=-1.15
var preview_ghost
var route_arrows
var selection_ring
var active_actor_marker
var scene_view
var ground_overlay
const MAP_PIXEL_SIZE=0.010727272727 # 99px Mara -> 90 logical px in reference camera at 1.25 scale.
var character_scale=1.0
var scene_render_scale=1.0 # Projection calibration only; never movement velocity.
var wait_advance_until=0
var map_touch=-1
var map_touch_start=Vector2.ZERO
var map_touch_last=Vector2.ZERO
var map_touch_dragged=false
const MAP_DRAG_THRESHOLD=12.0
# Map art only: never feed per-unit size into movement speed or combat art.
const MAP_RENDER_FACTORS={"oren":1.05}
func presentation_id(unit):
    var profile=PresentationProfiles.resolve(unit)
    return profile if not profile.is_empty() else unit.id
func presentation_id_for_instance(id):
    for unit in battle.units:
        if unit.id==id:return presentation_id(unit)
    return id
func map_render_factor(unit_id):return MAP_RENDER_FACTORS.get(presentation_id_for_instance(unit_id),1.0)*scene_render_scale

func _ready():
    if not App.session:App.new_game()
    session=App.session
    command_gate=CommandGate.new(self)
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
    board=BoardBuilder.new(self,battle.content)
    tiles=board.build()
    decorative_props=board.decorative_props
    preview_ghost=Sprite3D.new();preview_ghost.render_priority=2;preview_ghost.billboard=BaseMaterial3D.BILLBOARD_ENABLED;preview_ghost.flip_h=false
    preview_ghost.offset=Vector2(0,56);preview_ghost.modulate=Color(1.0,0.78,0.42,0.35);preview_ghost.pixel_size=MAP_PIXEL_SIZE;preview_ghost.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;preview_ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;preview_ghost.hide();add_child(preview_ghost)
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
    board_camera=BoardCamera.new(camera)
    route_mesh=MeshInstance3D.new();route_mesh.mesh=ImmediateMesh.new();add_child(route_mesh)
    route_arrows=MeshInstance3D.new();route_arrows.mesh=ImmediateMesh.new();add_child(route_arrows)
    var route_material=StandardMaterial3D.new();route_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;route_material.albedo_color=Color("e4c58a");route_material.cull_mode=BaseMaterial3D.CULL_DISABLED
    for node in [route_mesh,route_arrows]:node.material_override=route_material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visible=false
    board.build_props()
    decorative_props=board.decorative_props
    var iso_characters={}
    if FileAccess.file_exists("res://assets/sprites/iso4/manifest.json"):
        var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/iso4/manifest.json"))
        if manifest is Dictionary:iso_characters=manifest.get("characters",{})
    for u in battle.units:
        var sprite = preload("res://view/lit_character.gd").new()
        var profile_id=presentation_id(u)
        var art_role=PresentationProfiles.map_role(u)
        var art="res://assets/characters/"+profile_id+".png"
        if not ResourceLoader.exists(art):art="res://assets/sprites/"+art_role+".png"
        sprite.texture = load(art) if ResourceLoader.exists(art) else pixel_person(u.role,u.ally)
        sprite.set_meta("formal_art",ResourceLoader.exists(art))
        for direction in ["front","back","left","right"]:
            var path="res://assets/sprites/directional/"+art_role+"_"+direction+".png"
            if ResourceLoader.exists(path):direction_textures[u.id+":"+direction]=load(path)
        if iso_characters.has(art_role):
            var idle=iso_characters[art_role].get("idle",{});var loaded={}
            for direction in ["front_left","front_right","back_left","back_right"]:
                var file=idle.get(direction,"")
                if file is String and file.begins_with("assets/sprites/iso4/") and not file.contains("..") and ResourceLoader.exists("res://"+file):loaded[direction]=load("res://"+file)
            if loaded.size()==4:
                iso_roles[u.role]=true
                for direction in loaded:direction_textures[u.id+":"+direction]=loaded[direction]
        var reserve=preload("res://view/reserve_art.gd").profile(profile_id)
        if not reserve.is_empty():
            sprite.texture=reserve.map.back_right if u.ally else reserve.map.front_left
            sprite.set_meta("formal_art",true);iso_roles[u.role]=true
            for direction in reserve.map:direction_textures[u.id+":"+direction]=reserve.map[direction]
        var generic=preload("res://view/generic_map_art.gd").profile(profile_id)
        if not generic.is_empty():
            sprite.texture=generic.map.back_right if u.ally else generic.map.front_left
            sprite.set_meta("formal_art",true);iso_roles[u.role]=true
            hero_refresh_libraries[profile_id]=generic.library
            for direction in generic.map:direction_textures[u.id+":"+direction]=generic.map[direction]
        elif preload("res://view/generic_map_art.gd").declared(profile_id):
            sprite.texture=pixel_person(u.role,u.ally);sprite.set_meta("formal_art",false)
            for direction in direction_textures.keys():
                if direction.begins_with(u.id+":"):direction_textures.erase(direction)
        facing[u.id]=("back_right" if u.ally else "front_left") if iso_roles.has(u.role) else ("back" if u.ally else "front")
        last_positions[u.id]=u.pos
        sprite.pixel_size = MAP_PIXEL_SIZE*map_render_factor(u.id) if sprite.get_meta("formal_art") else 0.045
        sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
        sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED if sprite.get_meta("formal_art") else BaseMaterial3D.BILLBOARD_FIXED_Y
        if sprite.get_meta("formal_art"):sprite.offset=Vector2(0,56)
        sprite.padded_tessa_motion=profile_id=="tessa" and sprite.get_meta("formal_art")
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
    map_magic=preload("res://view/map_magic.gd").new();map_magic.game=self;add_child(map_magic)
    generic_attack_feedback=preload("res://view/generic_attack_feedback.gd").new();generic_attack_feedback.game=self;add_child(generic_attack_feedback)
    event_sequence=preload("res://view/event_sequence.gd").new();event_sequence.game=self;add_child(event_sequence);event_sequence.last_step=battle.step
    active_actor_marker=preload("res://view/active_actor_marker.gd").new();active_actor_marker.game=self;add_child(active_actor_marker)

# Shared entry point for map taps and HUD roster selection. Presentation only.
func select_actor(index):
    battle=session.logic
    if targeting_locked() or session.pending or not battle.usable(index):return false
    selected=index;hud.action_notice="";clear_move_preview()
    selection_pending_move=true
    refresh()
    return true
func observe_selection():
    var id=battle.units[selected].id if battle.usable(selected) else ""
    if not selection_initialized:
        selection_initialized=true;selection_seen_id=id;selection_seen_round=battle.round_number
        return
    if id!=selection_seen_id:
        selection_seen_id=id;selection_pending_move=not id.is_empty();selection_pending_focus=not id.is_empty()
        if scene_view:scene_view.cancel_focus()
    if battle.round_number!=selection_seen_round:
        selection_seen_round=battle.round_number
        if not id.is_empty():selection_pending_move=true
func apply_selection_presentation():
    if not selection_pending_move and not selection_pending_focus:return
    if targeting_locked() or session.pending:return
    if not battle.usable(selected):selection_pending_move=false;selection_pending_focus=false;return
    if selection_pending_focus and scene_view:
        var center=Vector3(battle.units[selected].pos.x,figure_height(selected),battle.units[selected].pos.y)
        center+=camera.global_basis.y*(56.0 if (not hero_refresh_entry(selected,facing.get(battle.units[selected].id,"front")).is_empty() or not elsbet_motion_entry(selected,facing.get(battle.units[selected].id,"front")).is_empty()) else figures[selected].offset.y)*figures[selected].pixel_size
        scene_view.focus_actor(center)
    selection_pending_focus=false
    if selection_pending_move:
        selection_pending_move=false;mode="move";clear_move_preview()
        preview_reachable=battle.reachable(selected)
        var can_move=false
        for cell in preview_reachable:
            if cell!=battle.units[selected].pos and not battle.path_to(selected,cell).is_empty():can_move=true;break
        hud.action_menu_open=not can_move

func select_mode(value):
    if presentation_active() or (hud and hud.blocks_input()):return
    observe_selection();selection_pending_move=false
    mode = value
    if hud:hud.action_menu_open=false
    refresh()

# Presentation-only proposal. No command is sent until explicit confirmation.
func stage_move(cell):
    if targeting_locked() or selected<0:return false
    pending_move={};update_move_preview(cell)
    if preview_path.is_empty():return false
    pending_move={"unit":selected,"actor_id":battle.units[selected].id,"step":battle.step,"cell":cell,"path":preview_path.duplicate(true),"state":proposal_state(),"checked_runtime":battle.get_instance_id(),"session_id":session.get_instance_id(),"connection":session.connection_generation,"mode":mode}
    hud.refresh();return true

func confirm_move():
    battle=session.logic
    if pending_move.is_empty():return false
    if targeting_locked():clear_move_preview();return false
    var proposal=pending_move.duplicate(true)
    var valid=mode=="move" and not command_gate.is_stale(proposal) and battle.units[selected].id==proposal.actor_id and battle.path_to(selected,proposal.cell)==proposal.path
    clear_move_preview()
    if not valid:hud.refresh();return false
    return dispatch_confirmation(proposal,{"kind":"move","unit":selected,"actor_id":proposal.actor_id,"x":proposal.cell.x,"y":proposal.cell.y})

func proposal_state():return command_gate.state()

func proposal_blocked():return command_gate.blocked()
func targeting_locked():return command_gate.locked()
func proposal_context_matches(proposal):return command_gate.context_matches(proposal)
func dispatch_confirmation(proposal,command):return command_gate.dispatch(proposal,command)
func flush_confirmation():command_gate.flush()

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
    pending_target={"unit":selected,"actor_id":battle.units[selected].id,"mode":mode,"step":battle.step,"state":proposal_state(),"checked_runtime":battle.get_instance_id(),"session_id":session.get_instance_id(),"connection":session.connection_generation,"target":target,"target_id":battle.units[target].id,"cell":cell,"command":target_command(target)}
    hud.refresh();return true

func confirm_proposal():
    battle=session.logic
    if not pending_move.is_empty():return confirm_move()
    if pending_target.is_empty():return false
    var proposal=pending_target.duplicate(true)
    var valid=not command_gate.is_stale(proposal)
    if valid:
        valid=battle.units[selected].id==proposal.actor_id and battle.at(proposal.cell)==proposal.target and battle.units[proposal.target].id==proposal.target_id and battle.preview_action(proposal.command).get("legal",false)
    clear_move_preview() # Consume before submit, including rejected/pending commands.
    if not valid:hud.refresh();return false
    return dispatch_confirmation(proposal,proposal.command)

func wait_proposal():
    return {"unit":selected,"mode":mode,"step":battle.step,"state":proposal_state(),"session_id":session.get_instance_id(),"connection":session.connection_generation}

func next_wait_actor():
    # Ask the same Lua command admission on a disposable VM, not UI counters.
    var probe=Runtime.new(battle.content)
    var snapshot=battle.snapshot()
    for offset in range(1,battle.units.size()):
        var index=(selected+offset)%battle.units.size()
        var unit=battle.units[index]
        if unit.controller!="player" or unit.hp<=0 or unit.faction!=battle.units[selected].faction:continue
        if not probe.restore(snapshot):return -2 # Fail closed; never end a turn on an invalid preview.
        if probe.apply_command({"kind":"wait","unit":index,"actor_id":unit.id,"step":battle.step+1}):return index
    return -1

func wait_selected():
    battle=session.logic
    if selected<0 or targeting_locked() or Time.get_ticks_msec()<wait_advance_until:return false
    if not battle.usable(selected):return false
    var actor=battle.units[selected]
    clear_move_preview()
    if actor.acted and actor.moves_used>=actor.move_actions:
        var next=next_wait_actor()
        if next==-2:return false
        if next>=0:
            if session.pending:
                hud.action_notice="等待同步完成后切换队员";hud.refresh();return false
            selected=next;selection_pending_move=true
            hud.action_notice="已切换至"+battle.units[next].name
            wait_advance_until=Time.get_ticks_msec()+350
            refresh();return true
        wait_advance_until=Time.get_ticks_msec()+350
        hud.action_notice="全员行动完毕，结束回合"
        return dispatch_confirmation(wait_proposal(),{"kind":"end_turn"})
    hud.action_notice=(actor.name+"已待机，再点待机切换队员") if not session.online else "等待待机同步确认"
    return dispatch_confirmation(wait_proposal(),{"kind":"wait","unit":selected,"actor_id":actor.id})

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
    if event_sequence:event_sequence.finish();event_sequence.last_step=-1
    selected = 0
    mode = "move"
    refresh()

func refresh():
    if route_mesh:clear_move_preview()
    target_preview={};target_preview_index=-1;target_hover_cell=Vector2i(-1,-1)
    if event_sequence:event_sequence.consume(battle.step,battle.events)
    if not battle.usable(selected):
        selected = -1
        for i in range(battle.units.size()):
            if battle.usable(i):
                selected = i
                break
    observe_selection()
    apply_selection_presentation()
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
        if not motion.motions.has(u.id):
            apply_map_idle_texture(i,facing.get(u.id,"front"))
        if not motion.motions.has(u.id):figures[i].position = Vector3(u.pos.x,figure_height(i),u.pos.y)
        badges[i].position = badge_position(i)
        badges[i].update_health(u.hp,u.max_hp,u.ally,i==selected)
    if hud:hud.refresh()
    if event_sequence:event_sequence.sync_visuals()

func _unhandled_input(event):
    if event is InputEventKey and event.pressed and not event.echo:
        if presentation_active() and event.physical_keycode in [KEY_SPACE,KEY_ENTER,KEY_ESCAPE]:skip_presentation();get_viewport().set_input_as_handled();return
        if event.physical_keycode==KEY_ESCAPE:
            if not hud.blocks_input() and not hud.action_menu_open:hud.cancel_targeting()
            else:hud.toggle_pause()
            return
        if hud.story_panel.visible and event.physical_keycode in [KEY_SPACE,KEY_ENTER]:hud.advance(false);return
    if not queued_confirmation.is_empty() and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
        hud.cancel_targeting();return
    if targeting_locked():
        map_touch=-1
        if queued_confirmation.is_empty():clear_move_preview()
        return
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
        if map_touch_dragged and map_touch!=-1:return
        if mode=="move" and not hud.action_menu_open and pending_move.is_empty():update_move_preview(mouse_cell(event.position))
        elif pending_target.is_empty():update_target_preview(mouse_cell(event.position))
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.index!=0 or map_touch!=-1 or hud.pointer_blocks_map(event.position):return
            if scene_view:scene_view.cancel_focus()
            map_touch=event.index;map_touch_start=event.position;map_touch_last=event.position;map_touch_dragged=false
        elif event.index==map_touch:
            var tap=not map_touch_dragged and not event.canceled and not hud.pointer_blocks_map(event.position)
            map_touch=-1
            if tap:tap_map(event.position)
        return
    if event is InputEventScreenDrag:
        if event.index!=map_touch:return
        if not map_touch_dragged and event.position.distance_to(map_touch_start)>=MAP_DRAG_THRESHOLD:
            map_touch_dragged=true;clear_move_preview();hud.refresh()
        if map_touch_dragged and scene_view:scene_view.pan_by(event.position-map_touch_last)
        map_touch_last=event.position
        return
    # GUI consumes its emulated mouse. Map touches above are submitted only on release.
    if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and event.device!=-1:
        tap_map(event.position)

func tap_map(point):
    if targeting_locked():return
    if scene_view:scene_view.cancel_focus()
    var cell=mouse_cell(point)
    if cell.x<0:
        clear_move_preview();hud.refresh();return
    var target = battle.at(cell)
    if target >= 0 and battle.units[target].controller=="player" and (mode=="move" or (mode=="attack" and selected>=0 and battle.units[target].faction==battle.units[selected].faction)):
        select_actor(target)
        return
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
    flush_confirmation()
    var proposal=pending_move if not pending_move.is_empty() else pending_target
    if not proposal.is_empty():
        if proposal_blocked() or not proposal_context_matches(proposal):clear_move_preview()
        elif battle.get_instance_id()!=proposal.checked_runtime:
            # Ordinary poll replies replace the VM even when the state is identical.
            if proposal_state()!=proposal.state:clear_move_preview()
            else:proposal.checked_runtime=battle.get_instance_id()
    if battle.step!=last_step:
        if hud:hud.action_menu_open=true
        last_step=battle.step
        refresh()
    observe_selection()
    apply_selection_presentation()
    if hud:hud.refresh() # refresh() ends with refresh_story(); avoid duplicate dock work.

func _exit_tree():
    if session:session.defer_poll=false # App owns the session across scenes.

func request_exit():hud.confirm_leave(true)

func projected_facing(from_cell,to_cell,diagonal=false):
    return board_camera.facing(from_cell,to_cell,diagonal)

func presentation_active():return (event_sequence and event_sequence.active()) or (motion and motion.active()) or (cutin and cutin.active)
func motion_finished():
    if event_sequence and event_sequence.active():event_sequence.motion_finished();return
    if hud:hud.action_menu_open=true
    if cutin:cutin.consume(battle.step,battle.events,battle.units,battle.content)
func skip_presentation():
    if event_sequence:event_sequence.finish();return
    if heal_feedback:heal_feedback.clear()
    if motion:motion.finish()
    if cutin:cutin.finish()

func mouse_cell(screen):
    return board_camera.cell_at(screen,scene_view)
func clear_move_preview():
    if not queued_confirmation.is_empty():session.defer_poll=false
    pending_move={};pending_target={};queued_confirmation={};target_preview={};target_preview_index=-1;target_hover_cell=Vector2i(-1,-1)
    preview_path=[];preview_reason="";preview_cell=Vector2i(-1,-1)
    if preview_ghost:preview_ghost.hide()
    route_mesh.mesh.clear_surfaces();route_arrows.mesh.clear_surfaces()
func update_move_preview(cell):
    if cell==preview_cell:return
    clear_move_preview();preview_cell=cell
    if selected<0 or mode!="move" or presentation_active() or hud.blocks_input():return
    preview_path=battle.path_to(selected,cell)
    if preview_path.is_empty():preview_reason="此格不可达 · 选择范围内的空格";return
    refresh_preview_ghost_art(selected)
    preview_ghost.pixel_size=figures[selected].pixel_size;preview_ghost.position=Vector3(cell.x,figures[selected].position.y,cell.y);preview_ghost.show()
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
    target_preview={};target_preview_index=-1;target_hover_cell=cell
    if selected<0 or mode=="move" or presentation_active() or hud.blocks_input():return
    var target=battle.at(cell)
    if target<0:return
    var command=target_command(target)
    var result=battle.preview_action(command)
    if result.get("legal",false):target_preview=result;target_preview_index=target

func figure_height(index):
    return 0.0 if figures[index].get_meta("formal_art") else 0.72
func figure_pixel_position(index,pixel):
    return board_camera.pixel_position(figures[index],pixel)
func badge_position(index):
    return figure_pixel_position(index,Vector2(48,0))+camera.global_basis.y*0.15 if figures[index].get_meta("formal_art") else figures[index].position+Vector3.UP*0.9
func badge_height(index):
    return badge_position(index).y
func set_character_scale(value):
    character_scale=clampf(value,0.5,1.5)
    for i in range(figures.size()):
        if figures[i].get_meta("formal_art"):figures[i].pixel_size=MAP_PIXEL_SIZE*character_scale*map_render_factor(battle.units[i].id)
        figures[i].position.y=figure_height(i)
        badges[i].position=badge_position(i)
    preview_ghost.pixel_size=figures[selected].pixel_size if selected>=0 and selected<figures.size() else MAP_PIXEL_SIZE*character_scale
    if preview_ghost.visible and selected>=0:preview_ghost.position.y=figure_height(selected)

# Shared neutral source for stationary entry and static movement.
# Animation is unit-scoped; unrelated Mod units keep their original art.
func base_directional_idle_texture(index,direction):
    var unit=battle.units[index]
    var generic=preload("res://view/generic_map_art.gd").profile(presentation_id(unit))
    if not generic.is_empty():return generic.map.get(direction,figures[index].texture)
    var reserve=preload("res://view/reserve_art.gd").profile(presentation_id(unit))
    if not reserve.is_empty():return reserve.map.get(direction,figures[index].texture)
    var fallback=direction_textures.get(unit.id+":"+direction,figures[index].texture)
    var idle=get_node_or_null("MapIdle")
    return idle.library.sample("map",PresentationProfiles.map_role(unit)+":"+direction,0.0,fallback,true,presentation_id(unit)) if idle else fallback

func hero_refresh_entry(index,direction):
    var id=presentation_id(battle.units[index])
    var enabled=preload("res://view/generic_map_art.gd").declared(id) or (App.rodd_motion_preview if id=="rodd" else App.hero_map_refresh_previews.get(id,false))
    if not enabled or not hero_refresh_libraries.has(id):return {}
    return hero_refresh_libraries[id].matching(id,direction,base_directional_idle_texture(index,direction))
func apply_map_idle_texture(index,direction,legacy_texture=null):
    # The motion start calls this helper with a neutral texture. Keep the padded
    # Elsbet motion root on that first frame, without replacing stopped idle.
    var id=battle.units[index].id
    if legacy_texture!=null and presentation_id(battle.units[index])=="elsbet" and motion and motion.motions.has(id) and not elsbet_motion_entry(index,direction).is_empty():
        apply_map_motion_texture(index,direction,motion.motions[id].get("travelled",0.0));return
    var entry=hero_refresh_entry(index,direction)
    var figure=figures[index]
    if not entry.is_empty():
        figure.texture=entry.idle.textures[0];figure.flip_h=entry.idle.flip_h;figure.offset=Vector2(0,64)
    else:
        figure.flip_h=false;figure.texture=directional_idle_texture(index,direction) if legacy_texture==null else legacy_texture
        if figure.get_meta("formal_art"):figure.offset=Vector2(0,56)
func refresh_preview_ghost_art(index):
    var direction=facing.get(battle.units[index].id,"front");var entry=hero_refresh_entry(index,direction)
    preview_ghost.texture=figures[index].texture if entry.is_empty() else entry.idle.textures[0]
    preview_ghost.flip_h=not entry.is_empty() and entry.idle.flip_h
    preview_ghost.offset=Vector2(0,64 if not entry.is_empty() else (52 if presentation_id(battle.units[index])=="tessa" and preview_ghost.texture.get_height()==136 else 56))
func directional_idle_texture(index,direction):
    var entry=hero_refresh_entry(index,direction)
    if not entry.is_empty():return entry.idle.textures[0]
    var neutral=base_directional_idle_texture(index,direction)
    return preload("res://view/map_sequence.gd").shared().idle(presentation_id(battle.units[index]),direction,0.0,neutral,true) if App.map_sequence_enabled(presentation_id(battle.units[index])) else neutral
func map_motion_neutral_texture(index,direction):
    var neutral=base_directional_idle_texture(index,direction)
    if App.map_sequence_enabled(presentation_id(battle.units[index])):
        var entry=preload("res://view/map_sequence.gd").shared().matching(presentation_id(battle.units[index]),direction,neutral)
        if not entry.is_empty() and entry.motion.is_empty():return neutral
    return directional_idle_texture(index,direction)
func neri_motion_entry(index,direction):
    if presentation_id(battle.units[index])!="neri" or not App.neri_motion_preview:return {}
    return neri_motion_library.matching("neri",direction,base_directional_idle_texture(index,direction))
func adela_motion_entry(index,direction):
    if presentation_id(battle.units[index])!="adela" or not App.adela_motion_preview:return {}
    return adela_motion_library.matching("adela",direction,base_directional_idle_texture(index,direction))
func vera_motion_entry(index,direction):
    if presentation_id(battle.units[index])!="vera" or not vera_motion_enabled:return {}
    return vera_motion_library.matching("vera",direction,base_directional_idle_texture(index,direction))
func elsbet_motion_entry(index,direction):
    if presentation_id(battle.units[index])!="elsbet" or not App.elsbet_motion_preview:return {}
    return elsbet_motion_library.matching("elsbet",direction,base_directional_idle_texture(index,direction))
func apply_map_motion_texture(index,direction,distance):
    var elsbet=elsbet_motion_entry(index,direction)
    if not elsbet.is_empty():
        if not is_finite(distance) or distance<0:apply_map_idle_texture(index,direction);return
        figures[index].texture=elsbet_motion_library.pick(elsbet.motion,distance)
        figures[index].flip_h=elsbet.motion.flip_h;figures[index].offset=Vector2(0,64);return
    var refreshed=hero_refresh_entry(index,direction)
    if not refreshed.is_empty():
        if not is_finite(distance) or distance<0:apply_map_idle_texture(index,direction);return
        figures[index].texture=hero_refresh_libraries[presentation_id(battle.units[index])].pick(refreshed.motion,distance)
        figures[index].flip_h=refreshed.motion.flip_h;figures[index].offset=Vector2(0,64);return
    if figures[index].get_meta("formal_art"):figures[index].offset=Vector2(0,56)
    var entry=vera_motion_entry(index,direction) if presentation_id(battle.units[index])=="vera" else adela_motion_entry(index,direction) if presentation_id(battle.units[index])=="adela" else neri_motion_entry(index,direction)
    figures[index].flip_h=is_finite(distance) and distance>=0 and not entry.is_empty() and entry.motion.get("flip_h",false)
    figures[index].texture=map_motion_texture(index,direction,distance)
func map_motion_texture(index,direction,distance):
    var elsbet=elsbet_motion_entry(index,direction)
    if not elsbet.is_empty() and is_finite(distance) and distance>=0:return elsbet_motion_library.pick(elsbet.motion,distance)
    var refreshed=hero_refresh_entry(index,direction)
    if not refreshed.is_empty():
        return hero_refresh_libraries[presentation_id(battle.units[index])].pick(refreshed.motion,distance) if is_finite(distance) and distance>=0 else refreshed.idle.textures[0]
    var unit=battle.units[index]
    if not vera_motion_entry(index,direction).is_empty():
        var trial=vera_motion_library.motion(presentation_id(unit),direction,distance,base_directional_idle_texture(index,direction))
        if trial!=null:return trial
    if not adela_motion_entry(index,direction).is_empty():
        var trial=adela_motion_library.motion(presentation_id(unit),direction,distance,base_directional_idle_texture(index,direction))
        if trial!=null:return trial
    if not neri_motion_entry(index,direction).is_empty():
        var trial=neri_motion_library.motion(presentation_id(unit),direction,distance,base_directional_idle_texture(index,direction))
        if trial!=null:return trial
    var sequence=null
    if App.map_sequence_enabled(presentation_id(unit)):sequence=preload("res://view/map_sequence.gd").shared().motion(presentation_id(unit),direction,distance,base_directional_idle_texture(index,direction))
    return sequence if sequence!=null else motion.walk_library.sample(presentation_id(unit),direction,distance,map_motion_neutral_texture(index,direction))
func figure_texture_pixel_position(index,pixel):
    # Public figure_pixel_position stays in the original 96px canonical coordinates.
    var texture=figures[index].texture
    if figures[index].flip_h:pixel.x=texture.get_width()-pixel.x
    var padding_y=figures[index].offset.y+texture.get_height()*0.5-120 if figures[index].get_meta("formal_art") else 0.0
    return figure_pixel_position(index,pixel-Vector2((texture.get_width()-96)*0.5,padding_y))
func refresh_map_sequence_art(actor_id=""):
    var idle=get_node_or_null("MapIdle")
    for i in range(figures.size()):
        var id=battle.units[i].id
        if not actor_id.is_empty() and id!=actor_id:continue
        if idle:idle.clocks.erase(id)
        var direction=facing.get(id,"front")
        if motion.motions.has(id):apply_map_motion_texture(i,direction,motion.motions[id].travelled)
        else:
            apply_map_idle_texture(i,direction)
    if preview_ghost.visible and selected>=0 and (actor_id.is_empty() or battle.units[selected].id==actor_id):
        refresh_preview_ghost_art(selected)

func refresh_elsbet_motion_art():
    if not motion or not motion.motions.has("elsbet"):return
    var moving=motion.motions.elsbet;apply_map_motion_texture(moving.index,facing.get("elsbet","front"),moving.travelled)
