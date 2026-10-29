extends SceneTree
func _initialize():call_deferred("run")
func frames():
    for i in range(8):await process_frame
func run():
    var app=root.get_node("App");app.new_game(Content.reference_content())
    change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    current_scene.refresh()
    Input.warp_mouse(current_scene.camera.unproject_position(Vector3(4,0,4)))
    await frames()
    current_scene.update_move_preview(Vector2i(4,4));await frames()
    await RenderingServer.frame_post_draw
    var image=root.get_texture().get_image();assert(image.save_png("res://docs/reference-hud-"+str(image.get_width())+"x"+str(image.get_height())+".png")==OK)
    print("REFERENCE_SCENE_CAPTURE ",image.get_size()," path=",current_scene.preview_path," hash=",app.session.logic.state_hash())
    quit()
