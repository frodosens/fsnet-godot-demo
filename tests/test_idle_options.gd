extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames(n=4):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://idle-options.cfg"
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;app.new_game();change_scene_to_file("res://main.tscn");await frames()
        while not app.next_story().is_empty():app.advance_story(true)
        var g=current_scene;g.refresh();g.hud.show_feedback_settings();await frames()
        var truth=g.battle.snapshot();var scroll=g.hud.modal.find_child("AnimationOptions",true,false)
        check(scroll==null,"obsolete animation options removed")
        var toggles=g.hud.modal.find_children("*","CheckButton",true,false)
        var actual=[]
        for toggle in toggles:actual.append(toggle.text)
        check(actual==["减弱震动与闪光","头顶血条自动避让","战斗音效"],"only unrelated accessible preferences remain")
        for toggle in toggles:
            var pos=toggle.get_global_rect().get_center();check(root.get_visible_rect().has_point(pos),"remaining control fits viewport")
            var before=toggle.button_pressed
            var click=InputEventMouseButton.new();click.position=pos;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;root.push_input(click,true);await process_frame
            click=click.duplicate();click.pressed=false;root.push_input(click,true);await frames()
            check(toggle.button_pressed!=before,"mouse operates remaining control")
            toggle.grab_focus();var key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;root.push_input(key,true);await process_frame
            key=key.duplicate();key.pressed=false;root.push_input(key,true);await frames()
            check(toggle.button_pressed==before,"keyboard restores remaining control")
        var output=OS.get_environment("AMBER_IDLE_STILLS")
        if not output.is_empty():
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(output+"/settings-"+str(size.x)+".png")
        var touch=InputEventScreenTouch.new();touch.index=0;touch.position=Vector2(12,12);touch.pressed=true;root.push_input(touch,true);await process_frame
        touch=touch.duplicate();touch.pressed=false;root.push_input(touch,true);await frames()
        check(g.battle.snapshot()==truth and g.pending_move.is_empty(),"modal prevents board input")
        g.hud.clear_modal();check(not g.hud.blocks_input(),"cancel restores interaction")
    print("IDLE_OPTIONS checks=",checks," failures=",failures);quit(1 if failures else 0)
