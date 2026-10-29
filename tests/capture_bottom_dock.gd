extends SceneTree
func _initialize():call_deferred("run")
func frames():
    for i in range(10):await process_frame
func shot(path):
    await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(path)
func run():
    root.size=Vector2i(1280,800)
    var app=root.get_node("App");app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();assert(game.scene_view.active)
    await shot("/tmp/dock-selected-1280.png")
    game.hud.choose_action("move");game.stage_move(Vector2i(4,4));await shot("/tmp/dock-preview-1280.png")
    root.size=Vector2i(960,600);await shot("/tmp/dock-preview-960.png")
    game.hud.cancel_targeting();await shot("/tmp/dock-selected-960.png")
    print("DOCK_CAPTURE_COMPLETE")
    quit()
