extends SceneTree
func _initialize():call_deferred("run")
func frames(n=5):
    for i in range(n):await process_frame
func run():
    var small="--small" in OS.get_cmdline_user_args();var after="--after" in OS.get_cmdline_user_args()
    root.size=Vector2i(960,600) if small else Vector2i(1280,800)
    var app=root.get_node("App");app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();assert(game.scene_view.set_fixed(true));game.update_move_preview(Vector2i(4,4));game.hud.refresh();await frames(10)
    await RenderingServer.frame_post_draw
    var suffix=("after" if after else "before")+"-"+str(root.size.x)
    root.get_texture().get_image().save_png("/tmp/amber-bounded-hud-"+suffix+".png")
    var scale=float(root.size.x)/root.get_visible_rect().size.x
    print("HUD_CAPTURE ",suffix," canvas=",root.get_visible_rect().size," action_font_px=",game.hud.action_buttons.move.get_theme_font_size("font_size")*scale," hp_font_px=",game.hud.hp_label.get_theme_font_size("font_size")*scale)
    quit()
