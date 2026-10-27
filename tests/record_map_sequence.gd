extends SceneTree
# Test placements, genuine rule paths, normal simulation timing. Output stays local.
func _initialize():call_deferred("run")
func frames(n):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://compact-record.cfg";app.sfx_enabled=false
    var output=OS.get_environment("AMBER_COMPACT_CAPTURE");assert(not output.is_empty())
    var fixed=OS.get_environment("AMBER_COMPACT_3D")!="1"
    for direction in preload("res://view/map_sequence.gd").DIRECTIONS:
        var data=preload("res://tests/walk_rear_fixture.gd").content("mara",direction)
        var target=preload("res://tests/walk_rear_fixture.gd").target(direction)
        if direction=="front_left":data.units[0].y=5;target=Vector2i(4,8)
        app.new_game(data);change_scene_to_file("res://main.tscn");await frames(4)
        while not app.next_story().is_empty():app.advance_story(true)
        var game=current_scene;game.refresh();game.scene_view.set_fixed(fixed);game.facing.mara=direction;game.selected=0
        app.set_mara_sequence_preview(true);game.refresh()
        var label=preload("res://ui/style.gd").label("玛拉关键帧试验 · "+direction+"\n合法测试摆位 · 每格一循环 · 单脚碎步未验收",18)
        label.position=Vector2(320,96);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;game.hud.root.add_child(label)
        await frames(100)
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output+"/"+direction+"-idle.png")
        assert(app.session.submit({"kind":"move","unit":0,"x":target.x,"y":target.y}))
        game.battle=app.session.logic;game.refresh()
        await frames(24)
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(output+"/"+direction+"-motion.png")
        while game.motion.active():await process_frame
        await frames(70)
    print("COMPACT_RECORD_COMPLETE normal_time=true weighted_distance=true fixed_background=",fixed);quit()
