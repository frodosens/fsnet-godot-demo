extends SceneTree
var checks=0
func _initialize():call_deferred("run")
func check(ok,label):
    checks+=1
    assert(ok,label)
func frames(n=4):
    for i in range(n):await process_frame
func click(button):
    var p=button.get_global_rect().get_center()
    var motion=InputEventMouseMotion.new();motion.position=p;root.push_input(motion,true);await frames(1)
    check(root.gui_get_hovered_control()==button or button.is_ancestor_of(root.gui_get_hovered_control()),"actual pointer reaches control")
    for down in [true,false]:
        var e=InputEventMouseButton.new();e.position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await process_frame
    await frames()
func button(prefix):
    for b in current_scene.find_children("*","Button",true,false):
        if b.is_visible_in_tree() and b.text.begins_with(prefix):return b
    return null
func check_fps():
    var label=root.get_node("App/FPSDisplay/FPSLabel")
    check(label.is_visible_in_tree() and label.text.begins_with("FPS "),"FPS visible")
    check(label.mouse_filter==Control.MOUSE_FILTER_IGNORE,"FPS ignores pointer")
    var rect=label.get_global_rect();check(root.get_visible_rect().encloses(rect),"FPS fits viewport")
    check(rect.end.y<=24,"FPS above status/menu controls")
func run():
    for size in [Vector2i(1280,800),Vector2i(960,600),Vector2i(1200,900)]:
        root.size=size;change_scene_to_file("res://ui/menu.tscn");await frames(6);await create_timer(.55).timeout
        check_fps();await click(button("开始新游戏"));await frames(5)
        check_fps();await click(button("暂停 / 保存"));check(is_instance_valid(current_scene.hud.modal),"pause opens through actual input")
        check_fps();await click(button("继续战斗"));await click(button("跳过本段"))
        check_fps();await click(current_scene.hud.turn_button);check(is_instance_valid(current_scene.hud.modal),"game input remains functional")
        await click(button("继续行动"));check(current_scene.battle.step==0,"cancel leaves rules unchanged")
    print("FPS_DISPLAY checks=",checks," failures=0 actual_graphical_pointer=true");quit()
