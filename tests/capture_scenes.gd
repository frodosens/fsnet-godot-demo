extends SceneTree
func _initialize():call_deferred("run")
func capture(name):
    for i in range(6):await process_frame
    await RenderingServer.frame_post_draw
    var result=root.get_texture().get_image().save_png("res://docs/"+name+".png")
    assert(result==OK)
    print("CAPTURE ",name)
func run():
    if DisplayServer.get_name()=="headless":printerr("Real renderer required");quit(1);return
    change_scene_to_file("res://ui/menu.tscn")
    await capture("menu-runtime")
    var app=root.get_node("App");app.new_game()
    change_scene_to_file("res://main.tscn")
    await process_frame;await process_frame
    current_scene.hud.advance(false)
    await capture("portrait-dialogue-runtime")
    current_scene.hud.advance(true)
    await capture("battle-ui-runtime")
    # Explicit small test fixture for the sword slice, using a real legal Lua attack.
    var data=Content.default_content();data.units[3].x=3;data.units[3].y=5
    app.new_game(data);change_scene_to_file("res://main.tscn")
    await process_frame;await process_frame
    current_scene.hud.advance(true)
    app.session.submit({"kind":"attack","unit":0,"target":3})
    current_scene.battle=app.session.logic;current_scene.refresh()
    var cutin=current_scene.cutin;cutin.set_process(false);cutin.draw_tick(11)
    await capture("sword-cutin-runtime")
    quit()
