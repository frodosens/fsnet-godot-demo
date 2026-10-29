extends SceneTree
func _initialize():call_deferred("run")
func frames(count):
    for i in range(count):await process_frame
func key(code):
    var event=InputEventKey.new();event.pressed=true;event.physical_keycode=code;current_scene._unhandled_input(event)
func run():
    var app=root.get_node("App");app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames(10)
    while not app.next_story().is_empty():app.advance_story(true)
    current_scene.refresh();await frames(30)
    var initial=app.session.logic.snapshot()
    key(KEY_2);await frames(24);key(KEY_1);await frames(24)
    var button=current_scene.hud.action_buttons.attack
    var motion=InputEventMouseMotion.new();motion.position=button.get_global_transform()*Vector2(100,32);root.push_input(motion,true);await frames(24)
    var mouse=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=motion.position;mouse.pressed=true;root.push_input(mouse,true);await frames(2);mouse.pressed=false;root.push_input(mouse,true);await frames(24)
    assert(current_scene.mode=="attack")
    key(KEY_1);current_scene.update_move_preview(Vector2i(4,4));await frames(30)
    assert(current_scene.hud.action_panel.visible and app.session.logic.snapshot()==initial)
    var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=current_scene.camera.unproject_position(Vector3(4,0,4));current_scene._unhandled_input(click)
    await frames(120)
    assert(app.session.logic.step==1 and current_scene.hud.action_buttons.move.disabled)
    await frames(30)
    print("HUD_SELECTION_RECORD_PASS keyboard_mouse_preview_move_disabled=true")
    quit()
