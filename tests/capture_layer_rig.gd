extends SceneTree
func _initialize():call_deferred("run")
func frames(n=8):
    for i in range(n):await process_frame
func shot(name):
    await frames();await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png("res://docs/"+name+".png")==OK)
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App");app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();assert(game.scene_view.set_fixed(true));var rig=game.layer_rig;assert(rig.available)
    var truth=game.battle.snapshot();var original=game.figures[0].texture
    rig.canvas.pelvis_drop=0;rig.canvas.pose(0,Vector2.ZERO);rig.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;game.figures[0].texture=rig.viewport.get_texture()
    await shot("mara-rig-neutral-runtime")
    rig.canvas.pelvis_drop=2
    var max_error=0.0
    for i in range(8):
        game.figures[0].texture=rig.draw_walk(0,"back_right",i/8.0,rig.stride*game.character_scale,Vector2(0,-1));max_error=maxf(max_error,rig.last_error)
        await frames();await RenderingServer.frame_post_draw
        rig.viewport.get_texture().get_image().save_png("/tmp/mara-rig-phase-%02d.png"%i)
    await shot("mara-rig-lit-runtime")
    for lamp in rig.game.scene_view.painted_lights:lamp.hide()
    for child in game.get_children():
        if child is DirectionalLight3D:child.hide()
    await shot("mara-rig-light-off-runtime")
    assert(game.battle.snapshot()==truth)
    game.figures[0].texture=original;rig.stop()
    print("LAYER_RIG_GPU_CAPTURE_PASS phases=8 max_clamp_px=",max_error," shared_state_unchanged=true")
    quit()
