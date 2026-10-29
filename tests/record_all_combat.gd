extends SceneTree
func _initialize():call_deferred("run")
func frames(count):
    for i in range(count):await process_frame
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App")
    # Explicit legal fixtures; one guaranteed crit proves rule-driven presentation.
    for pair in [[0,4],[1,5],[2,3],[3,0],[4,1],[5,2]]:
        var data=Content.default_content()
        for i in range(6):data.units[i].x=i;data.units[i].y=0;data.units[i].controller="player";data.units[i].hp=100
        var actor=pair[0];var target=pair[1]
        data.units[actor].x=3;data.units[actor].y=6;data.units[target].x=3;data.units[target].y=5
        data.abilities[0].crit_chance=100 if actor==0 else 0
        app.new_game(data);change_scene_to_file("res://main.tscn");await frames(10)
        while not app.next_story().is_empty():app.advance_story(true)
        var command={"kind":"attack","unit":actor,"target":target}
        if actor==2:command.kind="ability";command.ability="focus_bolt"
        assert(app.session.submit(command));current_scene.battle=app.session.logic;current_scene.refresh()
        var cutin=current_scene.cutin;assert(cutin.active);var snapshot=app.session.logic.snapshot()
        await frames(90)
        assert(app.session.logic.snapshot()==snapshot and not cutin.active and cutin.arena.position==cutin.layout_origin)
        print("SIX_ROLE_COMBAT ",data.units[actor].id," -> ",data.units[target].id," critical=",app.session.logic.events[0].is_critical," impact_play_count=",cutin.impact_play_count," hash=",app.session.logic.state_hash())
    quit()
