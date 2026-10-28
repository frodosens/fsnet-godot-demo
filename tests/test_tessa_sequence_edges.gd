extends SceneTree
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func frames(n=4):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://tessa-edges.cfg"
    app.save_root="user://compact-test-saves-"+str(Time.get_ticks_usec())
    DirAccess.remove_absolute(app.presentation_preferences_path);app.load_presentation_preferences()
    check(app.tessa_motion_preview,"accepted fresh local default on")
    var config=ConfigFile.new();config.set_value("map","tessa_motion_preview","true");config.save(app.presentation_preferences_path)
    app.load_presentation_preferences();check(app.tessa_motion_preview,"nonboolean preference rejected; use default on")
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size
        for fixed in [true,false]:
            var data=preload("res://tests/walk_rear_fixture.gd").content("tessa","front_right")
            data.units[1].x=6;data.units[1].y=7
            app.set_mara_sequence_preview(fixed)
            app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
            while not app.next_story().is_empty():app.advance_story(true)
            var game=current_scene;game.refresh();game.scene_view.set_fixed(fixed);game.motion.set_process(false)
            var truth=game.battle.snapshot()
            game.get_node("MapIdle").set_process(false)
            game.get_node("MapIdle").clocks.mara=.73
            var mara_texture=game.figures[0].texture
            app.set_tessa_motion_preview(false)
            game.hud.show_feedback_settings();await frames()
            var toggle
            for control in game.hud.modal.find_children("*","CheckButton",true,false):
                if control.text.begins_with("泰莎视频"):toggle=control
            check(toggle!=null,"settings entry")
            if toggle:
                game.hud.modal.find_child("AnimationOptions",true,false).ensure_control_visible(toggle);await frames()
                check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(toggle.get_global_rect()),"toggle on screen")
                var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=toggle.get_global_rect().get_center();click.pressed=true;root.push_input(click,true);await process_frame
                click=click.duplicate();click.pressed=false;root.push_input(click,true);await frames()
                check(app.tessa_motion_preview,"actual mouse enables candidate")
                check(game.get_node("MapIdle").clocks.mara==.73 and game.figures[0].texture==mara_texture,"Tessa setting does not reset Mara idle or image")
                toggle.grab_focus();var key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;root.push_input(key,true);await process_frame
                key=key.duplicate();key.pressed=false;root.push_input(key,true);await frames()
                check(not app.tessa_motion_preview,"keyboard restores old art")
            game.hud.clear_modal();app.set_tessa_motion_preview(true)
            check(game.select_actor(4),"select Tessa through actual selection lifecycle");await frames()
            var preview_texture=game.figures[4].texture
            game.update_move_preview(Vector2i(2,8));await frames()
            check(game.preview_ghost.visible and game.preview_ghost.texture==preview_texture,"preview current actor texture")
            check(game.preview_ghost.pixel_size==game.figures[4].pixel_size and game.preview_ghost.offset==game.figures[4].offset,"preview size/anchor same")
            check(game.battle.snapshot()==truth,"UI preview leaves rules")
            game.clear_move_preview()
            var path=game.battle.path_to(4,Vector2i(2,7));check(path.size()==3,"legal turn path")
            check(app.session.submit({"kind":"move","unit":4,"x":2,"y":7}),"real turning move")
            game.battle=app.session.logic;game.refresh();truth=game.battle.snapshot()
            game.motion.advance(1.2/game.character_scale)
            var second=game.projected_facing(Vector2i(path[1].x,path[1].y),Vector2i(path[2].x,path[2].y),true)
            check(game.facing.tessa==second,"turn selects correct direction")
            check(game.figures[4].texture==game.map_motion_texture(4,second,game.motion.motions.tessa.travelled),"turn phase distance continuous")
            var distance=game.motion.motions.tessa.travelled
            game.motion.consume(game.battle.step,game.battle.events)
            check(game.motion.motions.tessa.travelled==distance,"duplicate event no restart")
            game.motion.speed=8;game.motion.advance(10)
            check(not game.motion.active() and game.figures[4].position==Vector3(2,0,7),"large delta/fast completion")
            check(game.battle.snapshot()==truth,"turn preserves snapshot")
            check(app.save_slot("slot3")=="","real save")
            check(app.load_slot("slot3"),"real load")
            check(app.session.logic.snapshot()==truth,"save/load exact rule state")
            check(app.tessa_motion_preview,"local preference survives load")
            check(app.mara_sequence_preview==fixed,"Tessa toggle leaves Mara selection unchanged")
            app.set_tessa_motion_preview(false)
    print("TESSA_SEQUENCE_EDGES checks=",checks," failures=",failures);quit(1 if failures else 0)
