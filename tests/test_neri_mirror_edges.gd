extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.sfx_enabled=false;app.presentation_preferences_path="user://neri-edge.cfg"
    # Isolate the retained legacy fallback from the latest hero override.
    app.hero_map_refresh_previews={"mara":false,"finn":false,"neri":false}
    app.mara_sequence_preview=true;app.set_finn_motion_preview(true);app.set_oren_sequence_preview(true);app.set_bram_sequence_preview(true);app.set_tessa_motion_preview(true)
    app.set_idle_sequence_preview(true,"neri");app.set_idle_sequence_preview(true,"adela");app.set_idle_sequence_preview(true,"elsbet")
    var data=preload("res://tests/walk_rear_fixture.gd").content("neri","front_right")
    data.units[1].x=6;data.units[1].y=7
    app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.motion.set_process(false);game.get_node("MapIdle").set_process(false)
    var guard=game.base_directional_idle_texture(2,"front_right")
    var idle_before=game.directional_idle_texture(2,"front_right")
    for on in [true,false,true]:
        app.set_neri_motion_preview(on)
        require(game.directional_idle_texture(2,"front_right")==idle_before,"new switch cannot replace idle")
        require(app.mara_sequence_preview and app.finn_motion_preview and app.oren_sequence_preview and app.bram_sequence_preview and app.tessa_motion_preview,"five other trial options untouched")
        require(app.idle_sequence_previews=={"neri":true,"adela":true,"elsbet":true},"three idle switches untouched")
    require(app.session.submit({"kind":"move","unit":2,"x":2,"y":7}),"legal two segment corner")
    game.battle=app.session.logic;game.refresh();var path=game.motion.motions.neri.path
    require(path.size()==3,"real path has corner")
    game.motion.advance(.4/game.character_scale)
    require(game.figures[2].flip_h,"first segment front right mirrored")
    game.motion.advance(.8/game.character_scale)
    require(game.facing.neri=="back_right" and not game.figures[2].flip_h,"turn clears mirror on next segment")
    var pos=game.figures[2].position;var travel=game.motion.motions.neri.travelled
    game.refresh();require(game.figures[2].position==pos and game.motion.motions.neri.travelled==travel,"same step refresh preserves phase")
    game.motion.advance(100);require(not game.motion.active() and not game.figures[2].flip_h,"large delta settles unmirrored")
    game.motion.last_step=-1;game.motion.consume(game.battle.step,game.battle.events);game.motion.advance(.4/game.character_scale)
    require(game.figures[2].flip_h,"replay applies mirror only while moving")
    game.skip_presentation();require(not game.figures[2].flip_h,"skip restores idle")
    var snapshot=game.battle.snapshot();var replacement=Runtime.new(game.battle.content)
    require(replacement.restore(snapshot),"snapshot restore")
    game.session.logic=replacement;game.refresh();require(not game.motion.active() and not game.figures[2].flip_h and game.battle.snapshot()==snapshot,"restored state never replays mirror")
    game.neri_motion_library.configure({})
    game.apply_map_motion_texture(2,"front_right",.3)
    require(not game.figures[2].flip_h and game.figures[2].texture==game.motion.walk_library.sample("neri","front_right",.3,game.map_motion_neutral_texture(2,"front_right")),"bad profile fallback no mirror")
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;await frames();game.hud.show_feedback_settings();await frames()
        var scroll=game.hud.modal.find_child("AnimationOptions",true,false)
        require(scroll==null,"legacy animation controls removed")
        for option in game.hud.modal.find_children("*","CheckButton",true,false):
            require(not option.text.contains("移动") and not option.text.contains("待机"),"no replacement version checkbox")
        game.hud.clear_modal()
    print("NERI_MIRROR_EDGES checks=",checks," failures=0");quit()
