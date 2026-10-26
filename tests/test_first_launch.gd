extends SceneTree
var missing=false
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func click(button):
    var point=button.get_global_rect().get_center()
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point
        root.push_input(event,true)
        await process_frame
func run():
    missing="--missing-native" in OS.get_cmdline_user_args()
    change_scene_to_file("res://ui/menu.tscn");await frames(8)
    var app=root.get_node("App");var menu=current_scene
    await click(menu.page.get_child(1));await frames(8)
    if missing:
        assert(app.session==null and current_scene==menu and not menu.busy)
        assert(menu.feedback.text.contains("原生组件未加载"))
        if DisplayServer.get_name()!="headless":
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("/tmp/amber-missing-native.png")
        await click(menu.page.get_child(menu.page.get_child_count()-1));await frames()
        assert(menu.page.get_child(1).text.contains("开始新游戏"))
        print("FIRST_LAUNCH missing native: real mouse click shows actionable error; return works; no session")
    else:
        assert(current_scene is Node3D and current_scene.hud.story_panel.visible)
        print("FIRST_LAUNCH new game mouse click -> actual story scene")
        var game=current_scene
        game.hud.advance(true);game.refresh();game.hud.choose_action("move")
        var point=game.camera.unproject_position(Vector3(4,0,6))
        for pressed in [true,false]:
            var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point
            root.push_input(event,true);await process_frame
        game.motion.advance(2.0)
        await frames(3)
        assert(app.session.logic.step==1 and app.session.logic.units[0].pos==Vector2i(4,6))
        if DisplayServer.get_name()!="headless":
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("/tmp/amber-first-battle.png")
        print("FIRST_LAUNCH story -> actual target mouse click -> battle move step 1")
    quit()
