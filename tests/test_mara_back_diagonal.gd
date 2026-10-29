extends SceneTree
const Library=preload("res://view/map_sequence.gd")
const Fixture=preload("res://tests/walk_rear_fixture.gd")
const PATH="res://assets/sprites/iso4/mara_seedance_mini_v2/runtime_manifest.json"
var checks=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func frames():
    for i in range(3):await process_frame
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://mara-diagonal-test.cfg"
    var lib=Library.new(PATH)
    check(lib.errors.is_empty(),"current complete Mara profile admitted")
    var spec=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    for direction in ["back_left","back_right"]:
        var entry=lib.profiles.mara[direction]
        check(entry.motion.ticks==23 and entry.motion.ends==[3,6,9,12,14,18,20,23],"later-cycle holds preserved")
        check(entry.motion.flip_h==(direction=="back_left") and entry.idle.flip_h==(direction=="back_right"),"independent source facings")
        var bad=spec.duplicate(true);bad.profiles.mara[direction].motion.flip_h=not entry.motion.flip_h
        var invalid=Library.new();invalid.configure(bad);check(invalid.profiles.is_empty(),"wrong flip rejected")
        bad=spec.duplicate(true);bad.profiles.mara[direction].motion.source_facing="front_right"
        invalid.configure(bad);check(invalid.profiles.is_empty(),"front source cannot masquerade as back")
        for fixed in [true,false]:
            app.new_game(Fixture.content("mara",direction));change_scene_to_file("res://main.tscn");await frames()
            while not app.next_story().is_empty():app.advance_story(true)
            var game=current_scene;game.refresh();game.scene_view.set_fixed(fixed)
            game.motion.set_process(false);game.get_node("MapIdle").set_process(false)
            var figure=game.figures[0];var target=Fixture.target(direction)
            var start=Vector2i(game.battle.units[0].x,game.battle.units[0].y)
            check(game.projected_facing(start,target,true)==direction,"actual upward route direction")
            var delta=game.camera.unproject_position(Vector3(target.x,0,target.y))-game.camera.unproject_position(Vector3(start.x,0,start.y))
            check(delta.y<0 and ((delta.x<0)==(direction=="back_left")),"screen route goes up and correct side")
            check(app.session.submit({"kind":"move","unit":0,"x":target.x,"y":target.y}),"legal move through Lua")
            game.battle=app.session.logic;game.refresh();var truth=game.battle.snapshot();var seen={}
            for tick in range(1,58):
                game.motion.advance(.05/game.character_scale)
                var travel=game.motion.motions.mara.travelled
                check(figure.texture==lib.pick(entry.motion,travel),"actual sprite uses later cycle")
                seen[entry.motion.textures.find(figure.texture)]=true
                check(figure.flip_h==(direction=="back_left"),"actual right source mirrored only for left")
                check(game.figure_texture_pixel_position(0,Vector2(80,144)).is_equal_approx(figure.position),"fixed motion foot root")
                var pos=figure.position;game.refresh()
                check(figure.position==pos and game.motion.motions.mara.travelled==travel,"same step keeps phase")
            check(seen.size()==8 and not seen.has(-1),"all eight genuine frames played")
            game.motion.advance(.2/game.character_scale)
            check(not game.motion.active() and figure.position==Vector3(target.x,0,target.y),"natural stop reaches authority")
            check(figure.texture==entry.idle.textures[0] and figure.flip_h==entry.idle.flip_h,"natural stop retains existing idle source")
            game.get_node("MapIdle").advance(.7)
            check(figure.texture==entry.idle.textures[0] and game.battle.snapshot()==truth,"idle stable and rules unchanged")
            for turn in ["front_left","front_right","back_left","back_right"]:
                game.facing.mara=turn;game.apply_map_idle_texture(0,turn)
                var idle=lib.profiles.mara[turn].idle
                check(figure.texture==idle.textures[0] and figure.flip_h==idle.flip_h,"stopped facing uses original idle")
            game.motion.last_step=-1;game.motion.consume(game.battle.step,game.battle.events);game.motion.advance(.4)
            game.skip_presentation()
            check(not game.motion.active() and figure.texture==entry.idle.textures[0] and figure.flip_h==entry.idle.flip_h,"skip cleans moving mirror")
            app.new_game(Fixture.content("mara",direction));change_scene_to_file("res://main.tscn");await frames()
            while not app.next_story().is_empty():app.advance_story(true)
            game=current_scene;game.refresh();game.scene_view.set_fixed(fixed);game.motion.set_process(false)
            var corner=Vector2i(3,7);var path=game.battle.path_to(0,corner)
            check(path.size()==3,"legal two-segment rear corner")
            check(app.session.submit({"kind":"move","unit":0,"x":corner.x,"y":corner.y}),"submit actual rear turn")
            game.battle=app.session.logic;game.refresh();truth=game.battle.snapshot()
            for segment in range(2):
                game.motion.advance((.4 if segment==0 else 1.0)/game.character_scale)
                var facing=game.projected_facing(Vector2i(path[segment].x,path[segment].y),Vector2i(path[segment+1].x,path[segment+1].y),true)
                check(game.facing.mara==facing and game.figures[0].flip_h==lib.profiles.mara[facing].motion.flip_h,"rear turn changes source mirror correctly")
            game.skip_presentation()
            check(game.battle.snapshot()==truth and game.figures[0].position==Vector3(3,0,7),"turn skip keeps authoritative endpoint")
    print("MARA_BACK_DIAGONAL checks=",checks," failures=0");quit()
