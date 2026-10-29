extends SceneTree
func _initialize():call_deferred("run")
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App")
    for id in ["mara","finn","neri"]:
        var data=Content.default_content();data.units[3].x=3;data.units[3].y=5
        app.new_game(data);change_scene_to_file("res://main.tscn")
        for frame in range(12):await process_frame
        current_scene.hud.advance(true)
        var command={"kind":"attack","actor_id":id,"target_id":"oren"}
        if id=="neri":command.kind="ability";command.ability="focus_bolt"
        assert(app.session.submit(command));current_scene.battle=app.session.logic;current_scene.refresh()
        var settled=app.session.logic.state_hash()
        for frame in range(78):await process_frame
        assert(app.session.logic.state_hash()==settled)
        print("RECORDED_REAL_ATTACK ",id," settled_hash=",settled)
    quit()
