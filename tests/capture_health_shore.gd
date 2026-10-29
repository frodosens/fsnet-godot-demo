extends SceneTree
func _initialize():call_deferred("run")
func frames(n=8):
    for i in range(n):await process_frame
func shot(name):
    if "--thin-meter" in OS.get_cmdline_user_args():name="thin-"+name
    await frames();await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png("res://docs/"+name+".png")==OK)
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App");app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();assert(game.scene_view.set_fixed(true))
    await shot("health-shore-fixed-%dx%d"%[root.size.x,root.size.y])
    if "--shore-fixture" in OS.get_cmdline_user_args():
        var cases=[Vector2i(6,2),Vector2i(7,2),Vector2i(8,2),Vector2i(9,2),Vector2i(0,6),Vector2i(1,6),Vector2i(4,3),Vector2i(5,3),Vector2i(4,4),Vector2i(5,4),Vector2i(4,5),Vector2i(5,5)]
        for target in cases:
            # Explicit test fixture: same terrain and rules, isolated start positions for one legal step.
            var content=Content.reference_content().duplicate(true)
            var start=target+Vector2i(0,-1) if target.y<=5 else target+Vector2i(0,1)
            content.units[0].x=start.x;content.units[0].y=start.y
            content.units[3].x=6;content.units[3].y=0;content.units[4].x=7;content.units[4].y=0;content.units[5].x=8;content.units[5].y=0
            app.new_game(content);change_scene_to_file("res://main.tscn");await frames()
            while not app.next_story().is_empty():app.advance_story(true)
            game=current_scene;game.refresh();assert(game.scene_view.set_fixed(true))
            game.update_move_preview(target);assert(game.preview_path.size()==2)
            assert(app.session.submit({"kind":"move","unit":0,"x":target.x,"y":target.y}))
            game.battle=app.session.logic;game.refresh();game.skip_presentation();game.mode="attack";game.refresh()
            assert(game.battle.units[0].pos==target)
            await shot("shore-fixture-%d-%d"%[target.x,target.y])
            print("SHORE_LEGAL_COMMAND_PASS target=",target," spawn_fixture=true terrain_rules_unchanged=true")
    else:
        assert(game.scene_view.set_fixed(false));game.refresh();await shot("health-3d-%dx%d"%[root.size.x,root.size.y])
    print("HEALTH_SHORE_CAPTURE_PASS actual_window=",root.size)
    quit()
