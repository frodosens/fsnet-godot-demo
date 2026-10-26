extends SceneTree
func _initialize():call_deferred("run")
func frames():
    for i in range(8):await process_frame
func capture(name):
    await frames();await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png("res://docs/"+name+".png")==OK)
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App");app.scene_renderer="three_d";app.character_emission=0.35
    app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();Input.warp_mouse(game.camera.unproject_position(Vector3(4,0,4)));await frames();game.update_move_preview(Vector2i(4,4))
    await capture("ground-layer-3d-runtime")
    if "--only-3d-emission-off" in OS.get_cmdline_user_args():
        app.character_emission=0;await capture("character-emission-3d-off");quit();return
    assert(game.scene_view.set_fixed(true));await frames();game.update_move_preview(Vector2i(4,4))
    await capture("ground-layer-fixed-runtime")
    var initial=game.battle.snapshot();app.character_emission=0;await capture("character-emission-off")
    app.character_emission=0.35;await frames();assert(game.battle.snapshot()==initial)
    # Real three-cell move on the safe south dirt row, not the known bank-edge caveats.
    assert(app.session.submit({"kind":"move","unit":0,"x":1,"y":7}))
    game.battle=app.session.logic;game.refresh();game.skip_presentation();game.mode="attack";game.refresh()
    var truth=game.battle.snapshot()
    await capture("painted-lamps-on")
    var lights=[]
    for lamp in game.scene_view.painted_lights:
        lights.append({"id":lamp.get_meta("anchor_id"),"world":[lamp.position.x,lamp.position.y,lamp.position.z],"range":lamp.omni_range,"energy":lamp.light_energy,"distance_to_mara":lamp.position.distance_to(game.figures[0].position),"distance_to_oren":lamp.position.distance_to(game.figures[3].position)})
        lamp.hide()
    await capture("painted-lamps-off")
    assert(game.battle.snapshot()==truth)
    var file=FileAccess.open("res://docs/painted-light-anchors-runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(lights,"  "))
    print("LIGHTING_LAYER_CAPTURE_PASS emission=0.35 true_omni_lights=",lights.size()," snapshot_unchanged=true")
    quit()
