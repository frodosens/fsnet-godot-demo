extends SceneTree
var app
var game
var checks=0
var folder=OS.get_environment("AMBER_CONFIRM_CONTROL")
func _initialize():call_deferred("run")
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func frames(n=3):
    for i in range(n):await process_frame
func hold(t):await create_timer(t).timeout
func click(pos):
    var motion=InputEventMouseMotion.new();motion.position=pos;root.push_input(motion,true);await frames(1)
    for down in [true,false]:
        var e=InputEventMouseButton.new();e.position=pos;e.pressed=down;e.button_index=MOUSE_BUTTON_LEFT;root.push_input(e,true);await process_frame
    await frames()
func cell(pos):await click(game.camera.unproject_position(Vector3(pos.x,0,pos.y)))
func tap(b):await click(b.get_global_rect().get_center())
func wait_ready():
    for i in range(300):
        if app.session.ready and not app.session.pending:return
        await hold(.02)
    check(false,"connection ready timeout")
func wait_step(step):
    for i in range(300):
        if app.session.logic.step>=step:return
        await hold(.02)
    check(false,"step timeout")
func run():
    app=root.get_node("App");var port=int(OS.get_environment("AMBER_TEST_PORT"));var token=OS.get_environment("AMBER_TOKEN")
    check(app.start_room(false,port,token,preload("res://logic/content.gd").reference_content()),"real fsnet client starts")
    await wait_ready();change_scene_to_file("res://main.tscn");await frames(5);game=current_scene
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh();await frames();await tap(game.hud.action_buttons.move);await cell(Vector2i(4,6))
    var hash=game.battle.state_hash();var runtime_id=game.battle.get_instance_id()
    check(not game.pending_move.is_empty(),"actual first click staged")
    await hold(1.1)
    check(not game.pending_move.is_empty() and game.battle.state_hash()==hash and game.battle.get_instance_id()!=runtime_id,"slow preview survives several real poll VM replacements")
    # Reserve an actual outstanding poll; suspend only client reply consumption.
    await wait_ready();app.set_process(false);app.session.retry_clock=0;app.session.tick(0)
    check(app.session.pending and not app.session.command_pending,"ordinary poll really in flight")
    await cell(Vector2i(4,6));await cell(Vector2i(4,6));await cell(Vector2i(4,6))
    check(not game.queued_confirmation.is_empty() and app.session.request_id==0 and game.battle.step==0,"confirm during poll queues once without concurrent send")
    await hold(.3);check(not game.queued_confirmation.is_empty(),"slow reply cannot lose queued confirmation")
    app.set_process(true);await wait_step(1);await frames()
    check(game.battle.units[0].pos==Vector2i(4,6) and app.session.request_id==1,"queued move committed exactly once after poll")
    while game.presentation_active():await hold(.05)
    # Skill targets remain legal after moving; use the real ability menu.
    await tap(game.hud.action_buttons.skill)
    for b in game.hud.modal.find_children("*","Button",true,false):
        if b.text.begins_with("重整"):await tap(b);break
    await cell(Vector2i(4,6));await hold(1.1)
    check(not game.pending_target.is_empty() and game.battle.step==1,"ability target survives real polls")
    FileAccess.open(folder.path_join("remote-turn"),FileAccess.WRITE).store_string("go")
    await wait_step(2);await frames();check(game.pending_target.is_empty(),"other OS client action invalidates target")
    while game.presentation_active():await hold(.05)
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh();await frames();await tap(game.hud.action_buttons.move);await cell(Vector2i(4,7))
    check(not game.pending_move.is_empty(),"new turn proposal")
    var generation=app.session.connection_generation
    check(app.session.connect_local(port,token),"actual explicit reconnect")
    await frames();check(game.pending_move.is_empty() and app.session.connection_generation!=generation,"reconnect invalidates even unchanged state")
    await wait_ready();await frames();check(game.battle.step==2 and app.session.request_id==1,"no blind command retry after reconnect")
    await cell(Vector2i(4,7));check(not game.pending_move.is_empty(),"fresh click after reconnect previews")
    await wait_ready();app.set_process(false);app.session.retry_clock=0;app.session.tick(0)
    var enter=InputEventKey.new();enter.keycode=KEY_ENTER;enter.physical_keycode=KEY_ENTER;enter.pressed=true;root.push_input(enter,true);await frames()
    check(not game.queued_confirmation.is_empty() and app.session.request_id==1,"Enter during poll reserves one confirmation")
    await tap(game.hud.pause_button)
    check(game.queued_confirmation.is_empty() and not app.session.defer_poll,"pause cancels reserved confirmation and releases transport slot")
    var escape=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.physical_keycode=KEY_ESCAPE;escape.pressed=true;root.push_input(escape,true);await frames()
    app.set_process(true);await hold(.4);check(game.battle.step==2 and app.session.request_id==1,"cancelled queue never sends")
    await tap(game.hud.action_buttons.move);await cell(Vector2i(4,7))
    # Same-step changed snapshot is a protocol-edge fixture, not a server gameplay action.
    var altered=game.battle.content.duplicate(true);altered.units[0].hp-=1
    var alternate=preload("res://logic/runtime.gd").new(altered)
    check(alternate.apply_command({"kind":"move","unit":0,"x":4,"y":6,"step":1}) and alternate.apply_command({"kind":"end_turn","step":2}),"same-step alternate fixture")
    app.set_process(false)
    check(app.session.synchronize({"rules":game.battle.rules_hash,"content":game.battle.content_hash,"snapshot":alternate.snapshot(),"history":[],"hash":alternate.state_hash(),"step":2,"ack":1}),"validated same-step changed snapshot")
    await frames();check(game.pending_move.is_empty(),"same-step changed state discards proposal")
    print("NETWORK_TARGET_CONFIRM checks=",checks," failures=0 real_polls=true queued_once=true")
    FileAccess.open(folder.path_join("stop"),FileAccess.WRITE).store_string("stop");quit()
