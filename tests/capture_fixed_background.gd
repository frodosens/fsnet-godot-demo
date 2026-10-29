extends SceneTree
func _initialize():call_deferred("run")
func frames():
    for i in range(10):await process_frame
func capture(path):
    await frames();await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png(path)==OK)
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App");app.scene_renderer="three_d";app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh()
    if "--bridge-position" in OS.get_cmdline_user_args():
        assert(app.session.submit({"kind":"move","unit":0,"x":4,"y":4}))
        game.battle=app.session.logic;game.refresh();game.skip_presentation();game.mode="attack";game.refresh()
    Input.warp_mouse(game.camera.unproject_position(Vector3(4,0,4)));await frames();game.update_move_preview(Vector2i(4,4))
    var truth=game.battle.snapshot()
    var fixture="--fixture-guide" in OS.get_cmdline_user_args()
    if fixture:
        var image=Image.load_from_file("res://docs/fixed-background-geometry-guide.png")
        assert(game.scene_view.set_fixed(true,ImageTexture.create_from_image(image)))
        await frames();game.update_move_preview(Vector2i(4,4));await capture("/tmp/amber-fixed-guide-runtime.png")
    else:
        if not game.scene_view.available():printerr("BACKGROUND_UNAVAILABLE");quit(1);return
        await capture("res://docs/fixed-background-3d-comparison.png")
        assert(game.scene_view.set_fixed(true));await frames()
        Input.warp_mouse(game.camera.unproject_position(Vector3(4,0,4)));game.update_move_preview(Vector2i(4,4))
        await capture("res://docs/fixed-background-runtime.png")
        for light in game.get_children():
            if light is Light3D:light.visible=false
        await capture("res://docs/fixed-background-character-light-off.png")
    assert(game.battle.snapshot()==truth)
    print("FIXED_CAPTURE fixture=",fixture," snapshot_unchanged=true shadows=",game.scene_view.shadows.size()," renderer=",RenderingServer.get_video_adapter_name())
    quit()
