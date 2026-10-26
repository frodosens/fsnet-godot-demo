extends SceneTree
var checks=0
var failures=0
func check(value,label):
    checks+=1
    if not value:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func click(game,cell,button=MOUSE_BUTTON_LEFT):
    var event=InputEventMouseButton.new();event.button_index=button;event.pressed=true;event.position=game.camera.unproject_position(Vector3(cell.x,0,cell.y));game._unhandled_input(event)
func run():
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn")
    await process_frame;await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.hud.choose_action("move")
    var before=app.session.logic.snapshot()
    game.selected=1;click(game,Vector2i(4,7))
    check(game.selected==0 and app.session.logic.snapshot()==before,"click a player unit selects it without a command")
    check(game.preview_reachable.has(Vector2i(4,4)) and not game.preview_reachable.has(Vector2i(3,4)),"range comes from Lua and clips water")
    game.hud.choose_action("move");game.update_move_preview(Vector2i(4,4));var route=game.preview_path.duplicate(true)
    check(route.size()==4,"hover previews three steps without execution")
    click(game,Vector2i(4,4),MOUSE_BUTTON_RIGHT)
    check(game.preview_path.is_empty() and app.session.logic.snapshot()==before,"right-click cancels without cost or RNG")
    game.hud.choose_action("move");game.update_move_preview(Vector2i(4,4));var cancel=InputEventKey.new();cancel.pressed=true;cancel.physical_keycode=KEY_ESCAPE;game._unhandled_input(cancel)
    check(game.preview_path.is_empty() and app.session.logic.snapshot()==before,"Escape cancels without pausing or execution")
    game.hud.choose_action("move");click(game,Vector2i(3,4))
    check(app.session.logic.snapshot()==before and not game.preview_reason.is_empty(),"invalid destination does not move and retains reason")
    game.clear_move_preview();click(game,Vector2i(4,4))
    check(app.session.logic.snapshot()==before,"destination selection does not execute")
    check(game.confirm_move(),"explicit confirmation submits")
    check(app.session.logic.step==1 and app.session.logic.events[0].path==route,"confirmation submits entire shared path")
    check(game.motion.active() and game.motion.motions.mara.path==route,"walk animation consumes full authoritative path")
    var committed=app.session.logic.snapshot();click(game,Vector2i(4,3))
    check(app.session.logic.snapshot()==committed,"second click during motion cannot issue another command")
    game.motion.advance(4.0);game.hud.refresh()
    check(not game.motion.active() and Vector2i(roundi(game.figures[0].position.x),roundi(game.figures[0].position.z))==Vector2i(4,4),"automatic movement reaches final destination")
    check(game.hud.action_panel.visible and game.hud.action_buttons.move.disabled,"returns to actions with spent move disabled")
    print("MOVE_EVENT_PATH ",JSON.stringify(app.session.logic.events[0].path))
    print("MOVE_INTERACTION checks=",checks," failures=",failures," step=",app.session.logic.step)
    quit(1 if failures else 0)
