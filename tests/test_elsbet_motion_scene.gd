extends SceneTree
var checks=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func frames():
    for i in range(3):await process_frame
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://elsbet-scene.cfg"
    for fixed in [true,false]:
        for resolution in [Vector2i(1280,800),Vector2i(960,600)]:
            root.size=resolution
            for animated_idle in [false,true]:
                for direction in ["front_left","front_right","back_left","back_right"]:
                    var data=preload("res://tests/walk_rear_fixture.gd").content("elsbet",direction);var target=preload("res://tests/walk_rear_fixture.gd").target(direction)
                    app.new_game(data);change_scene_to_file("res://main.tscn");await frames();var game=current_scene
                    while not app.next_story().is_empty():app.advance_story(true)
                    game.refresh();game.selected=3;game.facing.elsbet=direction;game.scene_view.set_fixed(fixed);game.motion.set_process(false)
                    var idle=game.get_node("MapIdle");idle.set_process(false)
                    app.set_idle_sequence_preview(animated_idle,"elsbet");app.set_elsbet_motion_preview(false);idle.advance(.7)
                    var before=game.figures[3].texture;var clock=idle.clocks.get("elsbet",0.0);var other=game.figures[0].texture
                    app.set_elsbet_motion_preview(true)
                    check(game.figures[3].texture==before and idle.clocks.get("elsbet",0.0)==clock,"enabling movement preserves existing idle frame and clock")
                    check(game.figures[0].texture==other,"other actor untouched")
                    var entry=game.elsbet_motion_entry(3,direction);var figure=game.figures[3]
                    check(not entry.is_empty() and entry.motion.ticks==(20 if direction.begins_with("front") else 30),"direction-specific complete cycle")
                    game.mode="move";game.hud.action_menu_open=false;game.update_move_preview(target)
                    check(game.preview_ghost.texture.get_height()==128 and not game.preview_ghost.flip_h and game.preview_ghost.offset.y==56,"ghost retains old idle contract")
                    check(app.session.submit({"kind":"move","unit":3,"x":target.x,"y":target.y}),"legal move")
                    game.battle=app.session.logic;game.refresh();var snapshot=game.battle.snapshot();var scale=figure.pixel_size
                    check(figure.texture==entry.motion.textures[0] and figure.offset.y==64 and figure.flip_h==direction.ends_with("right"),"first movement frame has correct padding and mirror")
                    for tick in range(20):
                        game.motion.advance(.08/game.character_scale);var distance=game.motion.motions.elsbet.travelled
                        check(figure.texture==game.elsbet_motion_library.pick(entry.motion,distance),"one-grid weighted distance cadence")
                        check(game.figure_texture_pixel_position(3,Vector2(80,144)).is_equal_approx(figure.position),"motion root fixed")
                        check(figure.pixel_size==scale and figure.scale==Vector3.ONE,"body pixel scale unchanged")
                    var position=figure.position;var travel=game.motion.motions.elsbet.travelled
                    game.refresh();check(figure.position==position and game.motion.motions.elsbet.travelled==travel,"same state cannot restart motion")
                    game.motion.speed=0;game.motion.advance(1);check(figure.position==position,"zero speed pauses")
                    app.set_elsbet_motion_preview(false);check(figure.texture.get_height()==128 and not figure.flip_h and figure.offset.y==56,"midmotion rollback restores old root")
                    app.set_elsbet_motion_preview(true);check(figure.texture==game.elsbet_motion_library.pick(entry.motion,travel) and figure.position==position,"reenable resumes current travel")
                    game.skip_presentation();check(figure.texture==game.directional_idle_texture(3,direction) and not figure.flip_h and figure.offset.y==56,"skip restores original stopped idle")
                    idle.advance(.5);check(figure.texture.get_height()==128 and not figure.flip_h,"original idle updater still owns stopped actor")
                    check(game.battle.snapshot()==snapshot,"presentation never changes shared rules")
    print("ELSBET_MOTION_SCENE checks=",checks," failures=0");quit()
