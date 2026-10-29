extends SceneTree
func _initialize():call_deferred("run")
func frames(count=10):
    for i in range(count):await process_frame
func shot(name):
    if "--matrix" in OS.get_cmdline_user_args():name+="-%dx%d"%[root.size.x,root.size.y]
    await frames();await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png("res://docs/"+name+".png")==OK)
func run():
    var app=root.get_node("App");app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();assert(game.scene_view.set_fixed(true));await frames()
    var truth=game.battle.snapshot()
    game.set_character_scale(1.0);game.refresh();await shot("fixed-scale-before")
    game.set_character_scale(1.25);game.refresh();await shot("fixed-scale-status-after")
    Input.warp_mouse(game.camera.unproject_position(Vector3(4,0,4)));game.update_move_preview(Vector2i(4,4));await frames(45);await shot("fixed-ribbon-after")
    assert(game.battle.snapshot()==truth)
    assert(app.session.submit({"kind":"move","unit":0,"x":4,"y":4}));game.battle=app.session.logic;game.refresh();game.skip_presentation();game.mode="attack";game.refresh();await shot("fixed-scale-bridge-after")
    assert(game.scene_view.set_fixed(false));game.refresh();await shot("three-d-scale-preserved")
    print("SCALE_STATUS_CAPTURE_PASS rules_unchanged=true fixed_scale=1.25 restored_3d=1.0 physical_viewport=",root.size)
    quit()
