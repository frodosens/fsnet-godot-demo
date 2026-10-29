extends SceneTree
var checks=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://latest-map-policy.cfg"
    var keys=["rodd_motion_preview","elsbet_motion_preview","adela_motion_preview","neri_motion_preview","tessa_motion_preview","mara_sequence_preview","finn_motion_preview","oren_sequence_preview","bram_sequence_preview"]
    var config=ConfigFile.new()
    if OS.get_environment("LATEST_MAP_RESTART")!="1":
        for key in keys:config.set_value("map",key,false)
        for id in ["mara","finn","neri"]:config.set_value("map","hero_refresh_v2_"+id,false)
        for id in ["neri","adela","elsbet"]:config.set_value("map",id+"_idle_preview",false)
        config.set_value("map","neri_motion_default_version",999)
        config.set_value("map","health_bar_avoidance",true);config.set_value("custom","keep","yes")
        check(config.save(app.presentation_preferences_path)==OK,"old OFF fixture saved")
    var bytes=FileAccess.get_file_as_bytes(app.presentation_preferences_path)
    app.load_presentation_preferences()
    for key in keys:check(app.get(key)==true,"latest despite old OFF "+key)
    for id in app.hero_map_refresh_previews:check(app.hero_map_refresh_previews[id],"latest hero "+id)
    for id in app.idle_sequence_previews:check(app.idle_sequence_previews[id],"accepted idle "+id)
    check(app.health_bar_avoidance,"unrelated setting retained")
    check(bytes==FileAccess.get_file_as_bytes(app.presentation_preferences_path),"no destructive rewrite or legacy key restamp")
    app.new_game();var truth=app.session.logic.snapshot();app.load_presentation_preferences();check(app.session.logic.snapshot()==truth,"policy cannot mutate gameplay")
    for hero in ["mara","finn","neri","oren","bram","tessa","adela","elsbet","rodd","vera"]:
        for direction in ["front_left","front_right","back_left","back_right"]:
            app.new_game(preload("res://tests/walk_rear_fixture.gd").content(hero,direction));change_scene_to_file("res://main.tscn");await process_frame;await process_frame
            while not app.next_story().is_empty():app.advance_story(true)
            var g=current_scene;g.refresh();g.motion.set_process(false);g.get_node("MapIdle").set_process(false)
            var index=0
            for i in g.battle.units.size():
                if g.battle.units[i].id==hero:index=i
            var neutral=g.base_directional_idle_texture(index,direction);var expected
            if hero in ["mara","finn","neri","rodd"]:
                expected=g.hero_refresh_libraries[hero].motion(hero,direction,.45,neutral)
            elif hero=="elsbet":expected=g.elsbet_motion_library.motion(hero,direction,.45,neutral)
            elif hero=="adela":expected=g.adela_motion_library.motion(hero,direction,.45,neutral)
            elif hero=="vera":expected=g.vera_motion_library.motion(hero,direction,.45,neutral)
            else:expected=preload("res://view/map_sequence.gd").shared().motion(hero,direction,.45,neutral)
            check(expected!=null,"latest admitted clip exists "+hero+direction)
            var snapshot=g.battle.snapshot();g.apply_map_motion_texture(index,direction,.45)
            check(g.figures[index].texture==expected,"renderer uses latest actual resource "+hero+direction)
            var f=g.figures[index];var root_pixel=Vector2(f.texture.get_width()/2.0,f.texture.get_height()/2.0+f.offset.y)
            check(g.figure_texture_pixel_position(index,root_pixel).is_equal_approx(f.position),"latest padded root remains at logical actor position")
            check(f.scale==Vector3.ONE,"no per-frame body scale compensation")
            g.apply_map_idle_texture(index,direction)
            if hero=="elsbet":check(g.figures[index].texture==g.directional_idle_texture(index,direction) and not g.figures[index].flip_h,"Elsbet preserves accepted idle")
            check(g.battle.snapshot()==snapshot,"resource policy leaves state intact")
    print("LATEST_MAP_POLICY checks=",checks," failures=0 restart=",OS.get_environment("LATEST_MAP_RESTART"));quit()
