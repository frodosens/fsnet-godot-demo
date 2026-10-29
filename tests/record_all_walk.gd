extends SceneTree
func _initialize():call_deferred("run")
func frames(count):
    for i in range(count):await process_frame
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App")
    for actor in range(6):
        var data=Content.default_content()
        for i in range(6):data.units[i].x=i;data.units[i].y=0;data.units[i].controller="player"
        data.units[actor].x=1;data.units[actor].y=6
        app.new_game(data);change_scene_to_file("res://main.tscn");await frames(8)
        while not app.next_story().is_empty():app.advance_story(true)
        var game=current_scene;game.selected=actor
        assert(game.iso_roles.has(data.units[actor].role))
        assert(app.session.submit({"kind":"equip","unit":actor,"slot":5,"item":2}))
        var step=0
        for target in [Vector2i(2,6),Vector2i(2,7),Vector2i(1,7),Vector2i(1,6)]:
            if step==2:
                assert(app.session.submit({"kind":"end_turn"}))
                while not app.next_story().is_empty():app.advance_story(true)
            assert(app.session.submit({"kind":"move","unit":actor,"x":target.x,"y":target.y}))
            game.battle=app.session.logic;game.refresh();assert(game.motion.active());var snapshot=game.battle.snapshot()
            await frames(40)
            assert(not game.motion.active() and game.battle.snapshot()==snapshot)
            print("SIX_ROLE_ISO4_WALK ",data.units[actor].role," ",game.facing[data.units[actor].id])
            step+=1
    quit()
