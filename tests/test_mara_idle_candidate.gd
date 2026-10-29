extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");preload("res://tests/legacy_map_fixture.gd").apply(app);app.new_game(preload("res://logic/content.gd").reference_content())
    change_scene_to_file("res://main.tscn");await process_frame;await process_frame
    var game=current_scene;var idle=game.get_node("MapIdle");idle.set_process(false);game.motion.set_process(false)
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh();require(idle.library.errors.is_empty());require(idle.library.clips.map.size()==24);require(idle.library.clips.battle.keys()==["mara:right","oren:left","finn:right","neri:right","tessa:right","bram:right","oren:right"])
    var before=game.battle.snapshot();var position=game.figures[0].position
    for direction in ["front_left","front_right","back_left","back_right"]:
        game.facing.mara=direction;idle.clocks.clear();idle.advance(0)
        var clip=idle.library.clips.map["knight:"+direction]
        for phase in [0,1,2,3,0]:
            require(game.figures[0].texture==clip.textures[phase]);require(game.figures[0].position==position)
            idle.advance(0.4)
        game.hud.toggle_pause();var clock=idle.clocks.mara;var texture=game.figures[0].texture;idle.advance(3)
        require(idle.clocks.mara==clock);require(game.figures[0].texture==texture);game.hud.clear_modal();idle.advance(.4)
        require(idle.clocks.mara>clock)
    for i in range(1,6):
        var u=game.battle.units[i];var d=game.facing[u.id]
        require(game.figures[i].texture==idle.library.sample("map",u.role+":"+d,idle.clocks[u.id],game.direction_textures[u.id+":"+d],false,u.id))
    require(game.battle.snapshot()==before)
    require(app.session.submit({"kind":"move","unit":0,"x":3,"y":6}));game.battle=app.session.logic;game.refresh()
    var after=game.battle.snapshot();game.motion.advance(.2);idle.advance(.2)
    require(idle.clocks.mara==0)
    var neutral=game.directional_idle_texture(0,game.facing.mara)
    var travel=game.motion.motions.mara.travelled
    require(game.figures[0].texture==game.motion.walk_library.sample("mara",game.facing.mara,travel,neutral))
    game.motion.finish();idle.advance(0);require(game.figures[0].texture==idle.library.clips.map["knight:"+game.facing.mara].textures[0])
    idle.advance(.4);require(game.battle.snapshot()==after)
    # A scene replacement uses fresh presentation clocks; no persisted idle phase.
    change_scene_to_file("res://main.tscn");await process_frame;await process_frame
    require(current_scene.get_node("MapIdle")!=idle);require(current_scene.battle.snapshot()==after)
    print("MARA_IDLE_CANDIDATE checks=",checks," failures=0");quit()
