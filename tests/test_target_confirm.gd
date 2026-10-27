extends SceneTree
var app
var game
var checks=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func click(pos,touch=false):
    if not touch:
        var motion=InputEventMouseMotion.new();motion.position=pos;root.push_input(motion,true);await frames(1)
    for down in [true,false]:
        if touch:
            var e=InputEventScreenTouch.new();e.index=0;e.position=pos;e.pressed=down;root.push_input(e,true)
        else:
            var e=InputEventMouseButton.new();e.position=pos;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true)
        await process_frame
    await frames()
func cell(pos,touch=false):await click(game.camera.unproject_position(Vector3(pos.x,0,pos.y)),touch)
func tap(button):
    check(button.is_visible_in_tree() and not button.disabled,"enabled visible control")
    await click(button.get_global_rect().get_center())
func named(prefix):
    for b in game.find_children("*","Button",true,false):
        if b.is_visible_in_tree() and not b.disabled and b.text.begins_with(prefix):return b
    return null
func key(code):
    for down in [true,false]:
        var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e,true);await process_frame
    await frames()
func fresh():
    # Legal compact content fixture, not a forced outcome or altered live state.
    var data=preload("res://logic/content.gd").reference_content()
    data.units[3].x=5;data.units[3].y=7;data.units[5].x=4;data.units[5].y=6
    app.new_game(data);change_scene_to_file("res://main.tscn");await frames(5);game=current_scene
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh();await frames()
func run():
    app=root.get_node("App")
    await fresh()
    var before=game.battle.snapshot();await tap(game.hud.action_buttons.move)
    await cell(Vector2i(3,7));check(not game.pending_move.is_empty() and game.battle.snapshot()==before,"first movement tap only previews")
    await create_timer(1.1).timeout
    await cell(Vector2i(3,7));check(game.battle.step==1 and game.battle.units[0].pos==Vector2i(3,7),"slow second tap confirms, no OS double-click timeout")
    var committed=game.battle.snapshot();await cell(Vector2i(3,7));await cell(Vector2i(3,7));check(game.battle.snapshot()==committed,"extra taps while animation locked do not submit")
    await fresh();before=game.battle.snapshot();await tap(game.hud.action_buttons.attack)
    await cell(Vector2i(5,7));check(not game.pending_target.is_empty() and game.battle.snapshot()==before,"attack first tap only previews")
    await cell(Vector2i(4,6));check(game.pending_target.target_id=="bram" and game.battle.snapshot()==before,"different target replaces proposal")
    await cell(Vector2i(0,7));check(game.pending_target.is_empty() and game.battle.snapshot()==before,"invalid target discards proposal")
    await cell(Vector2i(5,7));await tap(game.hud.dock.cancel);check(game.pending_target.is_empty() and game.battle.snapshot()==before,"button cancels without cost")
    await tap(game.hud.action_buttons.attack);await cell(Vector2i(5,7));await tap(game.hud.pause_button)
    await key(KEY_ESCAPE);check(game.pending_target.is_empty() and game.battle.snapshot()==before,"pause invalidates target")
    await tap(game.hud.action_buttons.attack);await cell(Vector2i(5,7));await cell(Vector2i(5,7));await cell(Vector2i(5,7))
    check(game.battle.step==1 and game.session.request_id==1,"rapid attack taps submit once")
    await fresh();before=game.battle.snapshot();await tap(game.hud.action_buttons.skill);await tap(named("重整"))
    await cell(Vector2i(4,7));check(not game.pending_target.is_empty() and game.battle.snapshot()==before,"self skill still requires target confirmation")
    await key(KEY_ENTER);check(game.battle.step==1 and game.battle.units[0].acted,"keyboard confirms skill once")
    await fresh();before=game.battle.snapshot();await tap(game.hud.action_buttons.item);await tap(named("药房绷带"))
    await cell(Vector2i(4,7));check(game.battle.supplies[0]==2 and game.battle.snapshot()==before,"item preview consumes nothing")
    await tap(game.hud.dock.confirm);check(game.battle.step==1 and game.battle.supplies[0]==1,"confirm button consumes one item")
    await fresh();await tap(game.hud.action_buttons.attack);await cell(Vector2i(5,7));before=game.battle.snapshot()
    game.session.pending=true;game.session.command_pending=true;await frames();await cell(Vector2i(5,7));check(game.pending_target.is_empty() and game.battle.snapshot()==before,"pending network request blocks input and invalidates proposal");game.session.pending=false;game.session.command_pending=false
    await cell(Vector2i(5,7));check(not game.pending_target.is_empty(),"fresh target after pending")
    check(game.session.submit({"kind":"end_turn"}),"legal intervening authoritative state")
    await frames();check(game.pending_target.is_empty(),"new authoritative step discards proposal")
    await fresh();await tap(game.hud.action_buttons.attack);await cell(Vector2i(5,7));game.selected=1;await frames();check(game.pending_target.is_empty(),"actor change invalidates proposal")
    await fresh();await tap(game.hud.action_buttons.attack);await cell(Vector2i(5,7))
    # A legal alternative starting content produces a distinct authoritative state at step0.
    var altered=game.battle.content.duplicate(true);altered.units[0].hp-=1
    game.session.logic=preload("res://logic/runtime.gd").new(altered)
    check(not game.confirm_proposal() and game.session.request_id==0,"same-step replacement state cannot confirm stale target before next process")
    await fresh();await tap(game.hud.action_buttons.attack);await cell(Vector2i(5,7))
    game.mode="ability:rally";await frames();check(game.pending_target.is_empty(),"changed ability invalidates previous target")
    await fresh();await tap(game.hud.action_buttons.move)
    await cell(Vector2i(3,7),true);check(not game.pending_move.is_empty() and game.battle.step==0,"touch first tap previews")
    var emulated=InputEventMouseButton.new();emulated.position=game.camera.unproject_position(Vector3(3,0,7));emulated.button_index=MOUSE_BUTTON_LEFT;emulated.pressed=true;emulated.device=-1;root.push_input(emulated,true);await frames()
    check(game.battle.step==0 and not game.pending_move.is_empty(),"emulated mouse cannot double-submit a touch")
    await cell(Vector2i(3,7),true);check(game.battle.step==1,"touch second tap confirms")
    var fps=app.get_node("FPSDisplay").label
    for size in [Vector2i(1280,800),Vector2i(960,600),Vector2i(1200,900)]:
        root.size=size;await frames();check(fps.mouse_filter==Control.MOUSE_FILTER_IGNORE and fps.get_global_rect().end.x<=root.get_visible_rect().size.x,"FPS fits and ignores input")
    print("TARGET_CONFIRM checks=",checks," failures=0 mouse_touch_keyboard=true");quit()
