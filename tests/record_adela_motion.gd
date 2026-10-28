extends SceneTree
# Genuine rule paths at normal simulation speed; movie capture may render offline.
func _initialize():call_deferred("run")
func frames(n):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.sfx_enabled=false;app.presentation_preferences_path="user://adela-record.cfg"
    var output=OS.get_environment("AMBER_ADELA_CAPTURE");assert(not output.is_empty())
    var cases=[["front_right",false],["front_right",true],["front_left",true],["back_left",true],["back_right",true],["turn",true]]
    for entry in cases:
        var turning=entry[0]=="turn";var direction="front_right" if turning else entry[0];var on=entry[1]
        var data=preload("res://tests/walk_rear_fixture.gd").content("adela",direction)
        var target=preload("res://tests/walk_rear_fixture.gd").target(direction)
        if turning:data.units[0].y=6;data.units[1].x=6;data.units[1].y=7;target=Vector2i(2,7)
        app.new_game(data);change_scene_to_file("res://main.tscn");await frames(4)
        while not app.next_story().is_empty():app.advance_story(true)
        var game=current_scene;game.refresh();game.facing.adela=direction;game.selected=0
        app.set_idle_sequence_preview(false,"adela");app.set_adela_motion_preview(on);game.refresh()
        var title="阿黛拉双面板移动试验 · "+("转弯与停步" if turning else direction)+(" · 新素材" if on else " · 旧移动对照")
        var label=preload("res://ui/style.gd").label(title+"\n合法测试摆位 / 正常模拟速度 / 每格一循环"+("\n右侧镜像反转持械手，停止切回旧待机" if direction.ends_with("right") and on else ""),18)
        label.position=Vector2(300,90);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.hud.root.add_child(label)
        await frames(25)
        assert(app.session.submit({"kind":"move","unit":0,"x":target.x,"y":target.y}))
        game.battle=app.session.logic;game.refresh()
        await frames(25);await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output+"/"+("turn" if turning else direction)+("-trial" if on else "-old")+".png")
        while game.motion.active():await process_frame
        await frames(25)
    print("ADELA_MIRROR_RECORD normal_simulation_speed=true four_directions_and_corner=true");quit()
