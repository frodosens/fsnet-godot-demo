extends SceneTree
const Content=preload("res://logic/content.gd")
func _initialize():call_deferred("run")
func frames(count=4):
    for i in range(count):await process_frame
func capture(name):
    await frames();await RenderingServer.frame_post_draw
    var suffix=""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-suffix="):suffix="-"+arg.trim_prefix("--capture-suffix=")
    assert(root.get_texture().get_image().save_png("res://docs/"+name+suffix+".png")==OK)
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App");app.new_game();change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    current_scene.refresh();await capture("context-actions-runtime");var state=app.session.logic.snapshot()
    current_scene.update_move_preview(Vector2i(4,4))
    assert(current_scene.preview_path.size()==4 and app.session.logic.snapshot()==state)
    var preview=current_scene.preview_path.duplicate(true)
    await capture("shared-path-runtime")
    assert(app.session.submit({"kind":"move","unit":0,"x":4,"y":4}))
    assert(app.session.logic.events[0].path==preview)
    # Explicit guaranteed-critical content fixture, not a fabricated visual flag.
    var data=Content.default_content();data.units[3].x=3;data.units[3].y=5;data.units[3].hp=100;data.abilities[0].crit_chance=100
    app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    current_scene.refresh();current_scene.mode="attack";current_scene.update_target_preview(Vector2i(3,5));current_scene.hud.refresh()
    assert(not current_scene.target_preview.is_empty())
    await capture("target-preview-runtime")
    assert(app.session.submit({"kind":"attack","unit":0,"target":3}))
    current_scene.battle=app.session.logic;current_scene.refresh()
    var cutin=current_scene.cutin;cutin.set_process(false);cutin.draw_tick(cutin.hit_tick())
    assert(cutin.weapon_screen_point().distance_to(cutin.hurt_screen_point())<0.01)
    assert(cutin.event.is_critical)
    await capture("critical-contact-runtime")
    print("REAL_CONTACT_PATH_CAPTURE_PASS preview_matches_settled_path=true critical_fixture_chance=100")
    quit()
