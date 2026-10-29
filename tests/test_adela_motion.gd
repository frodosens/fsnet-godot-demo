extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.sfx_enabled=false
    app.presentation_preferences_path="user://adela-mirror-test.cfg"
    if FileAccess.file_exists(app.presentation_preferences_path):DirAccess.remove_absolute(app.presentation_preferences_path)
    app.load_presentation_preferences();require(app.adela_motion_preview and app.neri_motion_preview,"accepted Adela and Neri default on")
    var raw=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/adela_motion_trial.json"))
    var Library=load("res://view/map_sequence.gd")
    var library=Library.new("res://assets/animations/adela_motion_trial.json")
    require(library.errors.is_empty() and library.profiles.size()==1,"one valid independent profile")
    var profile=library.profiles.adela
    require(profile.front_right.motion.textures==profile.front_left.motion.textures,"FR aliases FL no duplicated images")
    for direction in Library.DIRECTIONS:
        var clip=profile[direction].motion
        require(clip.flip_h==(direction.ends_with("right")),"both right facings mirror")
        require(clip.ticks==25 and clip.root==Vector2(64,120),"timing/root")
        for i in range(8):
            var start=0 if i==0 else clip.ends[i-1]
            var phase=(start+0.5)/25.0
            require(library.pick(clip,phase)==clip.textures[i],"weighted interval")
    for bad in [null,1,"true",[],{}]:
        var altered=raw.duplicate(true);altered.profiles.adela.front_right.motion.flip_h=bad
        library.configure(altered);require(not library.profiles.has("adela") and not library.errors.is_empty(),"bad flip fails whole profile")
    for bad in [null,[],"bad"]:
        var altered=raw.duplicate(true);altered.profiles.adela.front_right.motion=bad
        library.configure(altered);require(not library.profiles.has("adela"),"bad nested motion safe")
    var absent=Library.new("user://no-adela-art.json");require(absent.profiles.is_empty(),"missing manifest fallback")
    var malformed=raw.duplicate(true);malformed.profiles.adela.front_right.motion.frames[0]="assets/missing-adela.png"
    library.configure(malformed);require(library.profiles.is_empty(),"missing texture no partial profile")
    app.finn_motion_preview=true;app.idle_sequence_previews.adela=true
    app.set_adela_motion_preview(true);app.load_presentation_preferences()
    require(app.adela_motion_preview,"local setting restores")
    for fixed in [true,false]:
        for physical in [Vector2i(1280,800),Vector2i(960,600)]:
            root.size=physical
            for direction in Library.DIRECTIONS:
                var data=preload("res://tests/walk_rear_fixture.gd").content("adela",direction)
                var target=preload("res://tests/walk_rear_fixture.gd").target(direction)
                app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
                while not app.next_story().is_empty():app.advance_story(true)
                var game=current_scene;game.refresh();game.scene_view.set_fixed(fixed);game.motion.set_process(false);game.get_node("MapIdle").set_process(false)
                var other_flips=[]
                for other in [1,2,3,4,5]:other_flips.append(game.figures[other].flip_h)
                var index=0;game.selected=index;var figure=game.figures[index]
                var neutral=game.directional_idle_texture(index,direction)
                game.facing.adela=direction;game.refresh();require(not figure.flip_h,"idle unmirrored")
                app.set_adela_motion_preview(true)
                require(app.session.submit({"kind":"move","unit":index,"x":target.x,"y":target.y}),"legal path")
                game.battle=app.session.logic;game.refresh();var truth=game.battle.snapshot();var size=figure.pixel_size
                for tick in range(1,50):
                    game.motion.advance(1.0/(25*game.character_scale))
                    var travel=game.motion.motions.adela.travelled;var entry=game.adela_motion_entry(index,direction)
                    require(figure.texture==game.adela_motion_library.motion("adela",direction,travel,entry.guard),"real travel sampling")
                    require(figure.flip_h==(direction.ends_with("right")),"motion mirror flag")
                    require(figure.pixel_size==size and figure.scale==Vector3.ONE,"no scale compensation")
                    require(game.figure_texture_pixel_position(index,Vector2(64,120)).is_equal_approx(figure.position),"center root unchanged")
                    var path=figure.texture.resource_path
                    require(path.contains('/'+(direction.replace("right","left"))+'/'),"source direction")
                var pos=figure.position
                app.set_adela_motion_preview(false);require(not figure.flip_h and figure.position==pos,"off mid-motion resets no teleport")
                app.set_adela_motion_preview(true);require(figure.flip_h==(direction.ends_with("right")) and figure.position==pos,"on resumes distance pose")
                game.motion.speed=0;var tex=figure.texture;game.motion.advance(1);require(figure.texture==tex and figure.position==pos,"pause stable")
                game.motion.speed=1;game.motion.finish();require(not figure.flip_h and figure.texture==neutral,"skip restores idle")
                require(game.battle.snapshot()==truth,"visual only state")
                for other in [1,2,3,4,5]:require(game.figures[other].flip_h==other_flips[other-1],"other actors unaffected")
                game.preview_ghost.flip_h=true;game.refresh_map_sequence_art("adela");game.preview_ghost.hide()
                # An ordinary legal new preview must explicitly clear any previous flip.
                game.hud.action_menu_open=false;game.mode="move";game.clear_move_preview()
                for dest in game.battle.reachable(index):
                    if dest!=game.battle.units[index].pos and not game.battle.path_to(index,dest).is_empty():
                        game.update_move_preview(dest);require(not game.preview_ghost.flip_h,"ghost never inherits mirror");break
    print("ADELA_MOTION checks=",checks," failures=0");quit()
