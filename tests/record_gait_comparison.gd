extends SceneTree
func _initialize():call_deferred("run")
func frames(count):
    for i in range(count):await process_frame
func run():
    assert(DisplayServer.get_name()!="headless")
    var old_dir=OS.get_environment("AMBER_GAIT_OLD_FRAMES")
    assert(not old_dir.is_empty())
    var old=[]
    for i in range(4):
        var image=Image.load_from_file(old_dir+"/%02d.png"%i);assert(image!=null);old.append(ImageTexture.create_from_image(image))
    var app=root.get_node("App")
    for revised in [false,true]:
        app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames(8)
        while not app.next_story().is_empty():app.advance_story(true)
        var game=current_scene
        if not revised:game.motion.frames.knight.front_right=old
        var caption=Label.new();caption.text="新：固定躯干 Contact / Pass" if revised else "旧：重复支撑姿态"
        caption.position=Vector2(400,75);caption.add_theme_font_size_override("font_size",22);game.hud.root.add_child(caption)
        game.refresh();game.update_move_preview(Vector2i(7,7));await frames(20)
        var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=game.camera.unproject_position(Vector3(7,0,7));game._unhandled_input(click)
        var truth=game.battle.snapshot()
        await frames(110)
        assert(not game.motion.active() and game.battle.snapshot()==truth and game.facing.mara=="front_right")
        print("GAIT_COMPARISON_PASS revised=",revised," path=",game.battle.events[0].path," hash=",game.battle.state_hash())
        await frames(12)
    quit()
