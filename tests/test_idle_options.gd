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
    var app=root.get_node("App");app.presentation_preferences_path="user://idle-options.cfg"
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;app.new_game();change_scene_to_file("res://main.tscn");await frames()
        while not app.next_story().is_empty():app.advance_story(true)
        var g=current_scene;g.refresh();g.hud.show_feedback_settings();await frames()
        var truth=g.battle.snapshot();var scroll=g.hud.modal.find_child("AnimationOptions",true,false)
        check(scroll!=null and scroll.clip_contents,"options clipped")
        check(root.get_visible_rect().encloses(scroll.get_global_rect()),"bounded scroll area")
        var toggles=scroll.find_children("*","CheckButton",true,false);check(toggles.size()==14,"fourteen animation controls including independent Rodd trial")
        var expected=["玛拉视频关键帧（候选）","芬恩视频移动（候选）","奥伦视频关键帧（暂用）","布拉姆视频关键帧（暂用）","泰莎视频移动（试验）","奈莉镜像移动（试验）","阿黛拉双面板移动（试验）","奈莉视频待机（暂用）","阿黛拉视频待机（暂用）","埃尔丝贝特视频待机（暂用）","玛拉地图重制 V2（试验）","芬恩地图重制 V2（试验）","奈莉地图重制 V2（试验）","罗德地图动作（试验）"]
        var actual=[]
        for toggle in toggles:actual.append(toggle.text)
        check(actual==expected,"exact animation control identities/order; no duplicates or missing options")
        for toggle in toggles:
            scroll.ensure_control_visible(toggle);await frames()
            var pos=toggle.get_global_rect().get_center();check(scroll.get_global_rect().has_point(pos),"each toggle reachable")
            var before=toggle.button_pressed
            var click=InputEventMouseButton.new();click.position=pos;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;root.push_input(click,true);await process_frame
            click=click.duplicate();click.pressed=false;root.push_input(click,true);await frames()
            check(toggle.button_pressed!=before,"mouse operates actual scroll control")
            toggle.grab_focus();var key=InputEventKey.new();key.keycode=KEY_SPACE;key.pressed=true;root.push_input(key,true);await process_frame
            key=key.duplicate();key.pressed=false;root.push_input(key,true);await frames()
            check(toggle.button_pressed==before,"keyboard restores control")
        var output=OS.get_environment("AMBER_IDLE_STILLS")
        if not output.is_empty():
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(output+"/settings-"+str(size.x)+".png")
        var touch=InputEventScreenTouch.new();touch.index=0;touch.position=Vector2(12,12);touch.pressed=true;root.push_input(touch,true);await process_frame
        touch=touch.duplicate();touch.pressed=false;root.push_input(touch,true);await frames()
        check(g.battle.snapshot()==truth and g.pending_move.is_empty(),"modal prevents board input")
        g.hud.clear_modal();check(not g.hud.blocks_input(),"cancel restores interaction")
    print("IDLE_OPTIONS checks=",checks," failures=",failures);quit(1 if failures else 0)
