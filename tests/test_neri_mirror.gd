extends SceneTree
var checks=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.sfx_enabled=false
    app.presentation_preferences_path="user://neri-mirror-test.cfg"
    if FileAccess.file_exists(app.presentation_preferences_path):DirAccess.remove_absolute(app.presentation_preferences_path)
    app.load_presentation_preferences();check(app.neri_motion_preview,"approved default on")
    # This test targets the retained legacy mirror fallback, not the Mini V2 profile.
    app.hero_map_refresh_previews={"mara":false,"finn":false,"neri":false}
    var raw=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/neri_motion_trial.json"))
    var Library=load("res://view/map_sequence.gd")
    var library=Library.new("res://assets/animations/neri_motion_trial.json")
    check(library.errors.is_empty() and library.profiles.size()==1,"one valid independent profile")
    var profile=library.profiles.neri
    check(profile.front_right.motion.textures==profile.front_left.motion.textures,"FR aliases FL no duplicated images")
    for direction in Library.DIRECTIONS:
        var clip=profile[direction].motion
        check(clip.flip_h==(direction=="front_right"),"only FR mirror")
        check(clip.ticks==29 and clip.root==Vector2(64,120),"timing/root")
        for i in range(8):
            var start=0 if i==0 else clip.ends[i-1]
            var phase=(start+0.5)/29.0
            check(library.pick(clip,phase)==clip.textures[i],"weighted interval")
    for bad in [null,1,"true",[],{}]:
        var altered=raw.duplicate(true);altered.profiles.neri.front_right.motion.flip_h=bad
        library.configure(altered);check(not library.profiles.has("neri") and not library.errors.is_empty(),"bad flip fails whole profile")
    for bad in [null,[],"bad"]:
        var altered=raw.duplicate(true);altered.profiles.neri.front_right.motion=bad
        library.configure(altered);check(not library.profiles.has("neri"),"bad nested motion safe")
    var absent=Library.new("user://no-neri-art.json");check(absent.profiles.is_empty(),"missing manifest fallback")
    var malformed=raw.duplicate(true);malformed.profiles.neri.front_right.motion.frames[0]="assets/missing-neri.png"
    library.configure(malformed);check(library.profiles.is_empty(),"missing texture no partial profile")
    app.finn_motion_preview=true;app.idle_sequence_previews.neri=true
    app.set_neri_motion_preview(true);app.load_presentation_preferences()
    check(app.neri_motion_preview,"latest selection restored")
    app.hero_map_refresh_previews={"mara":false,"finn":false,"neri":false}
    for fixed in [true,false]:
        for physical in [Vector2i(1280,800),Vector2i(960,600)]:
            root.size=physical
            for direction in Library.DIRECTIONS:
                var data=preload("res://tests/walk_rear_fixture.gd").content("neri",direction)
                var target=preload("res://tests/walk_rear_fixture.gd").target(direction)
                app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
                while not app.next_story().is_empty():app.advance_story(true)
                var game=current_scene;game.refresh();game.scene_view.set_fixed(fixed);game.motion.set_process(false);game.get_node("MapIdle").set_process(false)
                var index=2;game.selected=index;var figure=game.figures[index]
                var neutral=game.directional_idle_texture(index,direction)
                game.facing.neri=direction;game.refresh();check(not figure.flip_h,"idle unmirrored")
                app.set_neri_motion_preview(true)
                check(app.session.submit({"kind":"move","unit":index,"x":target.x,"y":target.y}),"legal path")
                game.battle=app.session.logic;game.refresh();var truth=game.battle.snapshot();var size=figure.pixel_size
                for tick in range(1,58):
                    game.motion.advance(1.0/(29*game.character_scale))
                    var travel=game.motion.motions.neri.travelled;var entry=game.neri_motion_entry(index,direction)
                    check(figure.texture==game.neri_motion_library.motion("neri",direction,travel,entry.guard),"real travel sampling")
                    check(figure.flip_h==(direction=="front_right"),"motion mirror flag")
                    check(figure.pixel_size==size and figure.scale==Vector3.ONE,"no scale compensation")
                    check(game.figure_texture_pixel_position(index,Vector2(64,120)).is_equal_approx(figure.position),"center root unchanged")
                    var path=figure.texture.resource_path
                    check(path.contains('/'+("front_left" if direction=="front_right" else direction)+'/'),"source direction")
                var pos=figure.position
                app.set_neri_motion_preview(false);check(not figure.flip_h and figure.position==pos,"off mid-motion resets no teleport")
                app.set_neri_motion_preview(true);check(figure.flip_h==(direction=="front_right") and figure.position==pos,"on resumes distance pose")
                game.motion.speed=0;var tex=figure.texture;game.motion.advance(1);check(figure.texture==tex and figure.position==pos,"pause stable")
                game.motion.speed=1;game.motion.finish();check(not figure.flip_h and figure.texture==neutral,"skip restores idle")
                check(game.battle.snapshot()==truth,"visual only state")
                for other in [0,1,3,4,5]:check(not game.figures[other].flip_h,"other actors unaffected")
                game.preview_ghost.flip_h=true;game.refresh_map_sequence_art("neri");game.preview_ghost.hide()
                # An ordinary legal new preview must explicitly clear any previous flip.
                game.hud.action_menu_open=false;game.mode="move";game.clear_move_preview()
                for dest in game.battle.reachable(index):
                    if dest!=game.battle.units[index].pos and not game.battle.path_to(index,dest).is_empty():
                        game.update_move_preview(dest);check(not game.preview_ghost.flip_h,"ghost never inherits mirror");break
    print("NERI_MIRROR checks=",checks," failures=0");quit()
