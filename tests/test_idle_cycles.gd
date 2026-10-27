extends SceneTree
var checks=0
func check(value):
    checks+=1
    assert(value)
func _initialize():call_deferred("run")
func run():
    var lib=preload("res://view/idle_library.gd").new()
    var fallback=load("res://assets/sprites/iso4/knight_back_right_idle.png")
    check(lib.sample("map","knight:back_right",99,fallback)==fallback)
    # Distinct existing poses are test sentinels, NOT accepted idle animation art.
    var map_clip={"frames":["assets/sprites/iso4/knight_back_right_idle.png","assets/sprites/iso4/knight_front_right_idle.png"],"frame_ms":[100,200]}
    var battle_clip={"frames":["assets/battle/mara/00_idle.png","assets/battle/mara/01_anticipation.png"],"frame_ms":[100,200]}
    lib.configure({"version":1,"map":{"knight:back_right":map_clip},"battle":{"mara:right":battle_clip}})
    check(lib.errors.is_empty());check(lib.sample("map","knight:back_right",0,fallback)==fallback)
    check(lib.sample("map","knight:back_right",0.11,fallback)!=fallback)
    check(lib.sample("map","knight:back_right",0.31,fallback)==fallback)
    check(lib.sample("map","knight:back_right",0.11,fallback,true)==fallback)
    for bad in [{"frames":["assets/../secret.png"],"frame_ms":[100]},{"frames":map_clip.frames,"frame_ms":[0,100]},{"frames":["assets/missing.png"],"frame_ms":[100]},battle_clip]:
        check(lib.decode(bad,Vector2i(96,128)).is_empty())
    var app=root.get_node("App");check(app.new_game(preload("res://logic/content.gd").reference_content()))
    var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
    await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh()
    var idle=game.get_node("MapIdle");idle.set_process(false);idle.library=lib
    var snapshot=game.battle.snapshot();var position=game.figures[0].position
    idle.advance(0.11);check(game.figures[0].texture!=fallback);check(game.figures[0].position==position)
    game.hud.toggle_pause();var time=idle.clocks.mara;idle.advance(10);check(idle.clocks.mara==time)
    game.hud.clear_modal();game.motion.motions.mara={};idle.advance(1);check(idle.clocks.mara==0)
    game.motion.motions.clear();idle.advance(0);check(game.figures[0].texture==fallback)
    game.facing.mara="front_right";idle.advance(0);check(idle.clocks.mara==0)
    check(game.figures[0].texture==game.direction_textures["mara:front_right"])
    check(game.battle.snapshot()==snapshot)
    var data=preload("res://logic/content.gd").reference_content();data.units[3].x=data.units[0].x+1;data.units[3].y=data.units[0].y
    var logic=preload("res://logic/runtime.gd").new(data);check(logic.apply_command({"kind":"attack","unit":0,"target":3,"step":1}))
    var cutin=load("res://ui/battle_cutin.gd").new();root.add_child(cutin);cutin.idle_library=lib
    var original=logic.snapshot();cutin.consume(logic.step,logic.events,logic.units,logic.content)
    cutin.draw_tick(1.5);check(cutin.attacker.texture==load("res://assets/battle/mara/01_anticipation.png"))
    cutin.draw_tick(cutin.hit_tick());check(cutin.defender.texture==load("res://assets/battle/oren/02_hit.png"))
    cutin.finish();check(not cutin.active and not cutin.surface.visible);check(logic.snapshot()==original)
    game.queue_free();await process_frame;check(not is_instance_valid(idle))
    print("IDLE_CYCLES checks=",checks," failures=0 (sentinel textures; no new art acceptance)");quit()
