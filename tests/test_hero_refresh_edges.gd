extends SceneTree
var checks=0
func check(value,label):
    checks+=1
    if not value:printerr("FAIL: ",label);quit(1)
    assert(value,label)
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://hero-edge.cfg"
    for hero in ["mara","finn","neri"]:
        var index=["mara","finn","neri"].find(hero)
        var data=preload("res://tests/walk_rear_fixture.gd").content(hero,"front_right")
        data.units[0].x=0;data.units[0].y=6;data.units[1].x=6;data.units[1].y=7
        data.units[index].x=1;data.units[index].y=6
        app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
        while not app.next_story().is_empty():app.advance_story(true)
        var game=current_scene;game.refresh();game.motion.set_process(false);game.get_node("MapIdle").set_process(false);game.selected=index
        var old_setting=app.neri_motion_preview;game.get_node("MapIdle").clocks.oren=.625
        app.set_hero_map_refresh_preview(true,hero)
        check(game.get_node("MapIdle").clocks.oren==.625 and app.neri_motion_preview==old_setting,"other clock/settings isolation")
        check(app.session.submit({"kind":"move","unit":index,"x":2,"y":7}),"legal corner")
        game.battle=app.session.logic;game.refresh();check(game.motion.motions[hero].path.size()==3,"actual two-segment path")
        game.motion.advance(.4/game.character_scale);check(game.figures[index].flip_h,"first segment mirrored")
        game.motion.advance(.8/game.character_scale);check(game.facing[hero]=="front_left" and not game.figures[index].flip_h,"turn changes both frame and mirror")
        var distance=game.motion.motions[hero].travelled;var position=game.figures[index].position
        var snapshot=game.battle.snapshot();var replacement=preload("res://logic/runtime.gd").new(game.battle.content)
        check(replacement.restore(snapshot),"same-state restore")
        game.session.logic=replacement;game.battle=replacement;game.refresh()
        check(game.motion.motions[hero].travelled==distance and game.figures[index].position==position,"VM replacement preserves phase")
        for scale in [.5,1.0,1.5]:
            game.set_character_scale(scale)
            check(game.figure_texture_pixel_position(index,Vector2(80,144)).is_equal_approx(game.figures[index].position),"scale keeps root")
        game.motion.speed=8;game.motion.advance(100)
        check(not game.motion.active() and game.figures[index].position==Vector3(2,0,7),"large delta stops at endpoint")
        var entry=game.hero_refresh_entry(index,"front_left")
        check(game.figures[index].texture==entry.idle.textures[0] and not game.figures[index].flip_h,"settle keeps grounded static idle")
        game.refresh();check(not game.motion.active(),"completed step never replays")
        var lib=game.hero_refresh_libraries[hero];lib.configure({})
        game.apply_map_idle_texture(index,"front_right")
        check(game.figures[index].texture.get_height()==128 and game.figures[index].offset==Vector2(0,56) and not game.figures[index].flip_h,"malformed profile restores old anchor/idle")
        check(game.battle.snapshot()==snapshot,"rules unchanged")
        app.set_hero_map_refresh_preview(false,hero)
    print("HERO_REFRESH_EDGES checks=",checks," failures=0");quit()
