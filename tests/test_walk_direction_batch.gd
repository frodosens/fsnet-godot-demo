extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames():
    for i in range(3):await process_frame
func run():
    var app=root.get_node("App");preload("res://tests/legacy_map_fixture.gd").apply(app);app.neri_motion_preview=false # Explicit old-motion baseline; default-on trial has separate tests.
    var Fixture=preload("res://tests/walk_rear_fixture.gd")
    var Walk=preload("res://view/walk_library.gd").shared();var Meter=load("res://view/unit_health.gd")
    for entry in [["finn","back_right"],["oren","back_left"],["oren","back_right"],["mara","front_right"],["bram","front_right"],["neri","front_right"],["tessa","front_right"],["adela","front_right"],["elsbet","front_right"],["mara","back_left"],["mara","back_right"],["bram","back_left"],["bram","back_right"]]:
        var actor=entry[0];var direction=entry[1]
        check(Walk.clips.has(actor+":"+direction),"expected registered direction")
        if not Walk.clips.has(actor+":"+direction):continue
        for fixed in [true,false]:
            var data=Fixture.content(actor,direction);var target=Fixture.target(direction)
            check(Content.validate(data)=="","legal fixture")
            app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
            while not app.next_story().is_empty():app.advance_story(true)
            var game=current_scene;game.refresh();game.scene_view.set_fixed(fixed);game.motion.set_process(false);game.get_node("MapIdle").set_process(false)
            var index=0
            for j in range(data.units.size()):
                if data.units[j].id==actor:index=j
            var neutral=game.directional_idle_texture(index,direction);var clip=Walk.clips[actor+":"+direction]
            check(clip.textures[0]==neutral and clip.textures[2]==neutral,"exact canonical N twice")
            check(app.session.submit({"kind":"move","unit":index,"x":target.x,"y":target.y}),"real legal Lua path")
            game.battle=app.session.logic;game.refresh();var truth=game.battle.snapshot()
            var bar=game.badges[index];bar._process(0);var width=bar.rendered_size.x
            for beat in range(1,12):
                game.motion.advance(.25/game.character_scale)
                check(game.facing[actor]==direction,"world direction matches binding")
                check(game.figures[index].texture==clip.textures[beat%4],"N L N R by actual distance")
                check(game.figure_pixel_position(index,Vector2(48,120)).is_equal_approx(game.figures[index].position),"foot anchor unchanged")
                check(bar.rendered_size.x==width,"fixed HP width stable")
                game.get_node("MapIdle").advance(.1)
                check(game.figures[index].texture==clip.textures[beat%4],"idle does not overwrite gait")
            game.motion.advance(.25/game.character_scale)
            check(not game.motion.active() and game.figures[index].texture==neutral,"stop on canonical neutral")
            check(game.battle.snapshot()==truth,"no rule mutation")
            game.motion.last_step=-1;game.motion.consume(game.battle.step,game.battle.events);game.motion.advance(.3);game.motion.finish()
            check(game.figures[index].texture==neutral and game.battle.snapshot()==truth,"skip/replay restores truth")
            # A fresh legal rule command with a turn, not invented animation coordinates.
            var corner_data=Fixture.content(actor,direction)
            if actor!="finn":corner_data.units[1].x=6;corner_data.units[1].y=7
            app.new_game(corner_data);change_scene_to_file("res://main.tscn");await frames()
            while not app.next_story().is_empty():app.advance_story(true)
            game=current_scene;game.refresh();game.scene_view.set_fixed(fixed);game.motion.set_process(false)
            var corner_target=Vector2i(2,7) if direction=="front_right" else Vector2i(3,7)
            var path=game.battle.path_to(index,corner_target)
            check(path.size()==3,"actual legal two-segment corner")
            check(app.session.submit({"kind":"move","unit":index,"x":corner_target.x,"y":corner_target.y}),"submit real corner command")
            game.battle=app.session.logic;game.refresh();truth=game.battle.snapshot()
            var first=game.projected_facing(Vector2i(path[0].x,path[0].y),Vector2i(path[1].x,path[1].y),true)
            var second=game.projected_facing(Vector2i(path[1].x,path[1].y),Vector2i(path[2].x,path[2].y),true)
            game.motion.advance(1.0/game.character_scale)
            check(game.figures[index].texture==game.directional_idle_texture(index,first),"whole-grid corner enters neutral")
            game.motion.advance(.25/game.character_scale)
            var fallback=game.directional_idle_texture(index,second)
            check(game.figures[index].texture==Walk.sample(actor,second,1.25,fallback),"turn selects new direction or fallback")
            game.motion.finish()
            check(game.battle.snapshot()==truth and game.figures[index].position==Vector3(corner_target.x,0,corner_target.y),"legal corner skip settles rule endpoint")
    for key in ["finn:front_left","finn:back_left","oren:front_left","adela:back_right","elsbet:back_right"]:check(not Walk.clips.has(key),"held/unproduced direction not enabled")
    print("WALK_DIRECTION_BATCH checks=",checks," failures=",failures);quit(1 if failures else 0)
