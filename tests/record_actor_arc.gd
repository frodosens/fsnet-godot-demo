extends SceneTree
func _initialize():call_deferred("run")
func frames(n):
    for i in range(n):await process_frame
func click(point):
    for pressed in [true,false]:
        var e=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;root.push_input(e,true);await process_frame
func run():
    root.size=Vector2i(1280,800)
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames(10)
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.scene_view.set_fixed(true);await frames(30)
    var truth=game.battle.snapshot()
    for kind in ["attack","skill","item","move"]:
        var e=InputEventMouseMotion.new();e.position=game.hud.action_buttons[kind].get_global_rect().get_center();root.push_input(e,true);await frames(24)
    assert(game.battle.snapshot()==truth)
    await click(game.hud.action_buttons.move.get_global_rect().get_center());await frames(12)
    assert(not game.hud.action_panel.visible)
    var destination=game.camera.unproject_position(Vector3(4,0,4))
    var hover=InputEventMouseMotion.new();hover.position=destination;root.push_input(hover,true);await frames(30)
    await click(destination);await frames(100)
    assert(game.battle.step==1 and game.battle.units[0].pos==Vector2i(4,4))
    assert(game.hud.action_panel.visible and game.hud.action_buttons.move.disabled)
    await frames(24)
    game.scene_view.set_fixed(false);await frames(6)
    var old=game.camera.global_transform
    for target in [Vector2(1190,390),Vector2(90,150)]:
        game.camera.global_transform=old
        var world=game.figures[0].position;var origin=game.camera.unproject_position(world)
        var px=game.camera.unproject_position(world+game.camera.global_basis.x).distance_to(origin)
        game.camera.global_position+=game.camera.global_basis.x*((origin.x-target.x)/px)+game.camera.global_basis.y*((target.y-origin.y)/px)
        await frames(40)
    print("ARC_RECORD_PASS actual_mouse_hover_click_move=true edge_camera_fixtures=true step=",game.battle.step)
    quit()
