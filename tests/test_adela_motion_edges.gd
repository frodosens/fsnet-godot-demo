extends SceneTree
var checks=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func touch(point,pressed):
    var event=InputEventScreenTouch.new();event.index=0;event.position=root.get_final_transform()*point;event.pressed=pressed
    Input.parse_input_event(event);Input.flush_buffered_events();await frames()
func run():
    Input.emulate_mouse_from_touch=true
    var app=root.get_node("App");app.sfx_enabled=false;app.presentation_preferences_path="user://adela-edge.cfg"
    app.mara_sequence_preview=true;app.set_finn_motion_preview(true);app.set_oren_sequence_preview(true);app.set_bram_sequence_preview(true);app.set_tessa_motion_preview(true)
    app.set_idle_sequence_preview(true,"neri");app.set_idle_sequence_preview(true,"adela");app.set_idle_sequence_preview(true,"elsbet")
    var data=preload("res://tests/walk_rear_fixture.gd").content("adela","front_right")
    data.units[0].y=6;data.units[1].x=6;data.units[1].y=7
    app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.motion.set_process(false);game.get_node("MapIdle").set_process(false)
    var guard=game.base_directional_idle_texture(0,"front_right")
    var idle_before=game.directional_idle_texture(0,"front_right")
    game.get_node("MapIdle").clocks.neri=0.875
    for on in [true,false,true]:
        app.set_adela_motion_preview(on)
        check(game.get_node("MapIdle").clocks.neri==0.875 and app.neri_motion_preview,"other actor clock and default untouched")
        check(game.directional_idle_texture(0,"front_right")==idle_before,"new switch cannot replace idle")
        check(app.mara_sequence_preview and app.finn_motion_preview and app.oren_sequence_preview and app.bram_sequence_preview and app.tessa_motion_preview,"five other trial options untouched")
        check(app.idle_sequence_previews=={"neri":true,"adela":true,"elsbet":true},"three idle switches untouched")
    check(app.session.submit({"kind":"move","unit":0,"x":2,"y":7}),"legal two segment corner")
    game.battle=app.session.logic;game.refresh();var path=game.motion.motions.adela.path
    check(path.size()==3,"real path has corner")
    game.motion.advance(.4/game.character_scale)
    check(game.figures[0].flip_h,"first segment front right mirrored")
    game.motion.advance(.8/game.character_scale)
    check(game.facing.adela=="front_left" and not game.figures[0].flip_h,"turn clears mirror on next segment")
    var pos=game.figures[0].position;var travel=game.motion.motions.adela.travelled
    game.refresh();check(game.figures[0].position==pos and game.motion.motions.adela.travelled==travel,"same step refresh preserves phase")
    game.motion.advance(100);check(not game.motion.active() and not game.figures[0].flip_h,"large delta settles unmirrored")
    game.motion.last_step=-1;game.motion.consume(game.battle.step,game.battle.events);game.motion.advance(.4/game.character_scale)
    check(game.figures[0].flip_h,"replay applies mirror only while moving")
    game.skip_presentation();check(not game.figures[0].flip_h,"skip restores idle")
    var snapshot=game.battle.snapshot();var replacement=preload("res://logic/runtime.gd").new(game.battle.content)
    check(replacement.restore(snapshot),"snapshot restore")
    game.session.logic=replacement;game.refresh();check(not game.motion.active() and not game.figures[0].flip_h and game.battle.snapshot()==snapshot,"restored state never replays mirror")
    game.adela_motion_library.configure({})
    game.apply_map_motion_texture(0,"front_right",.3)
    check(not game.figures[0].flip_h and game.figures[0].texture==game.motion.walk_library.sample("adela","front_right",.3,game.map_motion_neutral_texture(0,"front_right")),"bad profile fallback no mirror")
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;await frames();game.hud.show_feedback_settings();await frames()
        var scroll=game.hud.modal.find_child("AnimationOptions",true,false)
        check(scroll==null,"legacy animation controls removed")
        for option in game.hud.modal.find_children("*","CheckButton",true,false):
            check(not option.text.contains("移动") and not option.text.contains("待机"),"no replacement version checkbox")
        game.hud.clear_modal()
    print("ADELA_MOTION_EDGES checks=",checks," failures=0");quit()
