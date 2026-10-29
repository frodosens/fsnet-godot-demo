extends SceneTree
func _initialize():call_deferred("run")
func frames(n=24):
    for i in range(n):await process_frame
func click(b):
    for pressed in [true,false]:
        var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=b.get_global_rect().get_center();e.pressed=pressed;root.push_input(e,true);await process_frame
func destination(game):
    var p=game.camera.unproject_position(Vector3(4,0,4))
    for pressed in [true,false]:
        var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=p;e.pressed=pressed;root.push_input(e,true);await process_frame
func run():
    root.size=Vector2i(1280,800)
    var app=root.get_node("App");app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames(10)
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();assert(game.scene_view.active);var dock=game.hud.dock;await frames(30)
    await click(dock.action_nodes.move);await destination(game);await frames(35)
    assert(game.battle.step==0);await click(dock.cancel);await frames(24);assert(game.battle.step==0)
    await click(dock.action_nodes.move);await destination(game);await frames(30);await click(dock.confirm);await frames(100)
    assert(game.battle.step==1);await click(dock.action_nodes.wait);await frames(30);assert(game.battle.step==2 and game.battle.round_number==1)
    print("BOTTOM_DOCK_MOVIE_PASS mouse_confirm_cancel_wait=true")
    quit()
