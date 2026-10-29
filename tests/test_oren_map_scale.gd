extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames():
    for i in range(3):await process_frame
func run():
    var app=root.get_node("App");preload("res://tests/legacy_map_fixture.gd").apply(app);var data=preload("res://logic/content.gd").reference_content()
    data.units[3].ally=true;data.units[3].x=1;data.units[3].y=8
    app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.motion.set_process(false);game.get_node("MapIdle").set_process(false)
    var snapshot=game.battle.snapshot();var step=1000;game.selected=3
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;await frames()
        for fixed in [true,false]:
            game.scene_view.set_fixed(fixed);await frames()
            var global_scale=1.25 if fixed else 1.0
            check(is_equal_approx(game.character_scale,global_scale),"global motion scale unchanged")
            for i in range(6):
                check(is_equal_approx(game.figures[i].pixel_size/game.MAP_PIXEL_SIZE/global_scale,1.05 if i==3 else 1.0),"only Oren map enlarged")
            for direction in ["front_left","front_right","back_left","back_right"]:
                game.facing.oren=direction
                for phase in [0.0,.25,.5,.75]:
                    var neutral=game.directional_idle_texture(3,direction)
                    game.figures[3].texture=game.motion.walk_library.sample("oren",direction,phase,neutral)
                    check(game.figure_pixel_position(3,Vector2(48,120)).is_equal_approx(game.figures[3].position),"foot anchor locked")
                    var pixels=game.figures[3].pixel_size
                    check(is_equal_approx(pixels,game.MAP_PIXEL_SIZE*global_scale*1.05),"same scale every direction and pose")
                    game.badges[3]._process(0)
                    var width=game.badges[3].FIXED_WIDTH*minf(float(root.size.x)/root.get_visible_rect().size.x,float(root.size.y)/root.get_visible_rect().size.y)
                    check(game.badges[3].rendered_size.x<=width+.01,"base width remains independent of Oren actor scale")
                    check(game.badges[3].position.is_equal_approx(game.badge_position(3)),"meter follows scaled head anchor")
            game.select_mode("move");game.update_move_preview(Vector2i(2,8))
            check(game.preview_ghost.visible,"legal destination preview")
            check(is_equal_approx(game.preview_ghost.pixel_size,game.figures[3].pixel_size),"ghost same per-unit scale")
            check(game.preview_ghost.position.is_equal_approx(Vector3(2,0,8)),"ghost foot remains ground anchored")
            game.clear_move_preview()
            game.selected=0;game.select_mode("move");game.update_move_preview(Vector2i(3,6))
            check(game.preview_ghost.visible and is_equal_approx(game.preview_ghost.pixel_size,game.figures[0].pixel_size),"switching unit clears Oren ghost size")
            game.clear_move_preview();game.selected=3
            step+=1;game.motion.consume(step,[{"kind":"move","actor":"oren","path":[{"x":0,"y":8},{"x":1,"y":8}]}])
            game.motion.advance(.25/global_scale)
            check(is_equal_approx(game.motion.motions.oren.travelled,.25),"5 percent render size does not accelerate root")
            check(game.figures[3].texture==game.motion.walk_library.clips["oren:front_right"].textures[1],"one grid cadence unchanged")
            game.motion.advance(.75/global_scale)
            check(not game.motion.active() and game.figures[3].position==Vector3(1,0,8),"same full-grid duration and endpoint")
    check(game.battle.snapshot()==snapshot,"presentation scale leaves logic unchanged")
    for id in ["mara","finn","neri","tessa","bram","adela","elsbet","custom"]:check(game.map_render_factor(id)==1,"all other IDs unchanged")
    print("OREN_MAP_SCALE checks=",checks," failures=",failures);quit(1 if failures else 0)
