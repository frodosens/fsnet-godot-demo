extends SceneTree
func _initialize():call_deferred("run")
func wait_frames(count):
    for frame in range(count):await process_frame
func dismiss_story(app):
    while not app.next_story().is_empty():app.advance_story(true)
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App")
    for index in [0,5]:
        var data=Content.default_content()
        for i in range(data.units.size()):data.units[i].x=i;data.units[i].y=0;data.units[i].controller="player"
        data.units[index].x=1;data.units[index].y=6
        app.new_game(data);change_scene_to_file("res://main.tscn");await wait_frames(12);dismiss_story(app)
        current_scene.selected=index;current_scene.refresh()
        assert(current_scene.motion.frames.has(data.units[index].role))
        assert(app.session.submit({"kind":"equip","unit":index,"slot":5,"item":2}))
        var move=0
        for target in [Vector2i(3,6),Vector2i(3,7),Vector2i(1,7),Vector2i(1,6)]:
            if move==2:
                assert(app.session.submit({"kind":"end_turn"}));dismiss_story(app)
            assert(app.session.submit({"kind":"move","unit":index,"x":target.x,"y":target.y}))
            current_scene.battle=app.session.logic;current_scene.refresh();var hash=app.session.logic.state_hash()
            await wait_frames(45)
            assert(not current_scene.motion.active() and app.session.logic.state_hash()==hash)
            print("RECORDED_REAL_WALK ",data.units[index].role," ",current_scene.facing[data.units[index].id]," hash=",hash)
            move+=1
    quit()
