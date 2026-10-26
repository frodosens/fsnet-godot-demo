extends SceneTree
func _initialize():call_deferred("run")
func frames():
    for i in range(8):await process_frame
func shot(name):
    await frames();await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/ui-gallery-"+name+".png")
func run():
    root.size=Vector2i(1280,800)
    change_scene_to_file("res://ui/menu.tscn");await frames()
    await shot("home")
    current_scene.show_load();await shot("load")
    current_scene.show_network();await shot("network")
    root.size=Vector2i(960,600);await shot("network-960");root.size=Vector2i(1280,800)
    current_scene.cancel_network();current_scene.start_new();await frames()
    var game=current_scene;game.scene_view.set_fixed(true);await shot("story")
    while not root.get_node("App").next_story().is_empty():root.get_node("App").advance_story(true)
    game.refresh();game.hud.toggle_pause();await shot("pause")
    game.hud.clear_modal();game.selected=2;game.hud.show_abilities();await shot("skills")
    game.hud.clear_modal();game.hud.show_items();await shot("items")
    game.hud.clear_modal();game.hud.show_save();await shot("save")
    game.hud.clear_modal();game.hud.request_end_turn();await shot("confirmation")
    root.size=Vector2i(960,600);await shot("confirmation-960")
    game.hud.clear_modal();game.hud.show_items();await shot("items-960")
    print("UI_GALLERY_COMPLETE");quit()
