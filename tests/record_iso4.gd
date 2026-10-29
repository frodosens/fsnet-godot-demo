extends SceneTree
func _initialize():call_deferred("run")
func wait_frames(count):
    for frame in range(count):await process_frame
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App");var data=Content.default_content()
    data.units[0].x=1;data.units[0].y=6
    app.new_game(data);change_scene_to_file("res://main.tscn");await wait_frames(12)
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene
    assert(game.iso_roles.has("knight") and game.motion.frames.knight.has("front_right"))
    assert(app.session.submit({"kind":"move","unit":0,"x":3,"y":6}))
    game.battle=app.session.logic;game.refresh();var state=game.battle.snapshot()
    assert(game.motion.active())
    await wait_frames(45)
    assert(not game.motion.active() and game.battle.snapshot()==state)
    print("ISO4_REAL_MOVE complete supported_direction=front_right hash=",game.battle.state_hash())
    # Turntable: explicit visual QA, not commands or additional gameplay movement.
    for direction in ["front_right","front_left","back_left","back_right"]:
        game.facing.mara=direction;game.figures[0].texture=game.direction_textures["mara:"+direction]
        await wait_frames(30)
        assert(game.battle.snapshot()==state)
        print("ISO4_IDLE_VISUAL_QA ",direction)
    quit()
