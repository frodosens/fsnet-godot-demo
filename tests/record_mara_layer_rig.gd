extends SceneTree
func _initialize():call_deferred("run")
func frames(count):
    for i in range(count):await process_frame
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App")
    for enabled in [false,true]:
        app.mara_layer_preview=enabled;app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames(8)
        while not app.next_story().is_empty():app.advance_story(true)
        var game=current_scene;game.refresh();assert(game.scene_view.set_fixed(true));assert(game.layer_rig.available)
        game.motion.speed=1.0 if enabled else game.layer_rig.stride/0.5 # Same world speed in both clips; only pose method changes.
        var caption=Label.new();caption.text="新：连续分层 IK · 小步样板" if enabled else "旧：序列帧 · 同位移速度对照";caption.position=Vector2(390,80);caption.add_theme_font_size_override("font_size",22);game.hud.root.add_child(caption)
        await frames(12)
        var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=game.camera.unproject_position(Vector3(4,0,6));game._unhandled_input(click)
        var truth=game.battle.snapshot();var worst=0.0;var samples=0;var clamped=0
        while game.motion.active() and samples<300:
            await process_frame;samples+=1;worst=maxf(worst,game.layer_rig.last_error)
            if enabled and game.layer_rig.last_error>0.01:clamped+=1
        assert(not game.motion.active() and game.battle.units[0].pos==Vector2i(4,6) and game.battle.snapshot()==truth)
        print("MARA_RIG_RECORD enabled=",enabled," frames=",samples," max_clamp_px=",worst," clamped_frames=",clamped," same_world_speed=true")
        await frames(18)
    app.mara_layer_preview=false
    print("MARA_RIG_RECORD_PASS old_new_real_shared_move=true")
    quit()
