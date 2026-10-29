extends SceneTree
# Genuine rule paths at normal simulation speed; movie capture may render offline.
func _initialize():call_deferred("run")
func frames(n):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.sfx_enabled=false;app.presentation_preferences_path="user://neri-record.cfg"
    var output=OS.get_environment("AMBER_NERI_CAPTURE");assert(not output.is_empty())
    var cases=[["front_right",false],["front_right",true],["front_left",true],["back_left",true],["back_right",true]]
    for entry in cases:
        var direction=entry[0];var on=entry[1]
        var data=preload("res://tests/walk_rear_fixture.gd").content("neri",direction)
        var target=preload("res://tests/walk_rear_fixture.gd").target(direction)
        app.new_game(data);change_scene_to_file("res://main.tscn");await frames(4)
        while not app.next_story().is_empty():app.advance_story(true)
        var game=current_scene;game.refresh();game.facing.neri=direction;game.selected=2
        app.set_idle_sequence_preview(false,"neri");app.set_neri_motion_preview(on);game.refresh()
        var title="奈莉移动镜像试验 · "+direction+(" · 新素材" if on else " · 旧三姿态移动对照")
        var label=Style.label(title+"\n合法测试摆位 / 正常模拟速度 / 每格一循环"+(" / 右前镜像会反转持杖手" if direction=="front_right" and on else ""),18)
        label.position=Vector2(300,90);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.hud.root.add_child(label)
        await frames(25)
        assert(app.session.submit({"kind":"move","unit":2,"x":target.x,"y":target.y}))
        game.battle=app.session.logic;game.refresh()
        await frames(25);await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output+"/"+direction+("-trial" if on else "-old")+".png")
        while game.motion.active():await process_frame
        await frames(25)
    print("NERI_MIRROR_RECORD normal_simulation_speed=true old_FR_not_original_video_TR=true");quit()
