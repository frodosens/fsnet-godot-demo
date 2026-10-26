extends SceneTree
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App")
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--save-root="):app.save_root=arg.trim_prefix("--save-root=")
    assert(app.load_slot("auto"))
    change_scene_to_file("res://main.tscn")
    for i in range(8):await process_frame
    assert(current_scene.battle.outcome=="victory")
    var unit=current_scene.battle.units[maxi(0,current_scene.selected)]
    assert(current_scene.hud.hp_label.text=="%d/%d"%[unit.hp,unit.max_hp])
    assert(current_scene.hud.hint_label.text.contains("保存或返回") and current_scene.hud.turn_button.disabled)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/amber-loop-victory-after.png")
    print("TERMINAL_SAVE_RENDER_PASS restored_actual_UI_victory_save=true")
    quit()
