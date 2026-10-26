extends SceneTree
func _initialize():call_deferred("run")
func frames(count):
    for i in range(count):await process_frame
func hover(game,cell):
    var point=game.camera.unproject_position(Vector3(cell.x,0,cell.y));Input.warp_mouse(point)
    var event=InputEventMouseMotion.new();event.position=point;root.push_input(event,true)
    game.update_move_preview(cell)
func run():
    assert(DisplayServer.get_name()!="headless")
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames(8)
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();assert(game.scene_view.set_fixed(true));await frames(8)
    var truth=game.battle.snapshot()
    for cell in [Vector2i(4,6),Vector2i(5,6),Vector2i(3,6),Vector2i(4,4)]:
        hover(game,cell);await frames(24)
        assert(game.preview_path.size()>=2)
    assert(game.battle.snapshot()==truth)
    var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.position=game.camera.unproject_position(Vector3(4,0,4));game._unhandled_input(event)
    await frames(90)
    assert(game.battle.step==1 and game.battle.units[0].pos==Vector2i(4,4) and not game.motion.active())
    assert(game.ground_overlay.last_path.is_empty())
    print("ROUTE_RIBBON_RECORD_PASS real_mouse_hover=true single_click=true automatic_path=true shared_step=1")
    quit()
