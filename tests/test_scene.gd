extends SceneTree
func _initialize():call_deferred("run")
func run():
    var game=load("res://main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    var app=root.get_node("App")
    app.advance_story(true)
    game.hud.refresh_story()
    var click=InputEventMouseButton.new()
    click.button_index=MOUSE_BUTTON_LEFT
    click.pressed=true
    click.position=game.camera.unproject_position(Vector3(3,0,5))
    game._unhandled_input(click)
    if game.battle.step!=1 or game.battle.units[0].pos!=Vector2i(3,5):
        printerr("mouse picking -> command -> Lua failed");quit(1);return
    game.skip_presentation()
    var key=InputEventKey.new()
    key.physical_keycode=KEY_SPACE
    key.pressed=true
    game._unhandled_input(key)
    if game.battle.step!=1 or not is_instance_valid(game.hud.modal):
        printerr("unused-actions confirmation missing");quit(1);return
    game.hud.confirm_end_turn()
    if game.battle.step!=2 or game.battle.round_number!=2:
        printerr("end turn input failed");quit(1);return
    game.restart()
    if game.battle.step!=0 or game.battle.units[0].pos!=Vector2i(3,6):
        printerr("restart failed");quit(1);return
    if game.projected_facing(Vector2i(0,0),Vector2i(1,0))!="right" or game.projected_facing(Vector2i(0,0),Vector2i(0,1))!="front":
        printerr("camera facing mapping failed");quit(1);return
    print("SCENE_INPUT_TEST_PASS mouse move + keyboard end turn + restart")
    game.queue_free()
    await process_frame
    quit(0)
