extends SceneTree
var app
var game
var checks=0
var folder=OS.get_environment("AMBER_DETAILS_CONTROL")
func _initialize():call_deferred("run")
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func frames(n=3):
    for i in range(n):await process_frame
func hold(t):await create_timer(t).timeout
func click(point):
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true);await process_frame
    await frames()
func ready():
    for i in range(400):
        if app.session.ready and not app.session.pending:return
        await hold(.02)
    check(false,"ready timeout")
func step(value):
    for i in range(400):
        if app.session.logic.step>=value:await frames();return
        await hold(.02)
    check(false,"step timeout")
func settle():
    app.session.defer_poll=true;await ready();await frames()
func run():
    app=root.get_node("App");var port=int(OS.get_environment("AMBER_TEST_PORT"));var token=OS.get_environment("AMBER_TOKEN")
    check(app.start_room(false,port,token,preload("res://logic/content.gd").reference_content()),"real fsnet room connection")
    await ready();change_scene_to_file("res://main.tscn");await frames(5);game=current_scene
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh();await frames();await click(game.hud.dock.details_button.get_global_rect().get_center())
    var page=game.hud.modal;check(is_instance_valid(page),"real bottom control opens details online")
    await click(page.tabs[3].get_global_rect().get_center());page.choose_slot(5);page.choose_equipment(2)
    var hash=game.battle.state_hash();var runtime=game.battle.get_instance_id()
    await hold(1.1)
    check(game.battle.state_hash()==hash and game.battle.get_instance_id()!=runtime,"actual polling replaces Runtime without changing state")
    check(page.tab==3 and page.slot==5 and page.selected_uid==2,"polls preserve selection")
    # Hold consumption of a real in-flight poll: no fake pending flag.
    await ready();app.set_process(false);app.session.retry_clock=0;app.session.tick(0)
    check(app.session.pending and not app.session.command_pending,"real poll outstanding")
    await click(page.equip.get_global_rect().get_center())
    check(app.session.request_id==0 and game.battle.step==0,"poll-busy equip cannot send concurrently")
    app.set_process(true);await settle();page.refresh_data();page.choose_equipment(2)
    var preview=page.model.preview_equipment(game.battle,0,5,2)
    check(preview.allowed,"preview remains legal after poll")
    # Suspend reply consumption after submitting through the actual control.
    app.set_process(false);await click(page.equip.get_global_rect().get_center())
    check(app.session.command_pending and app.session.pending,"equip command really pending")
    await click(page.equip.get_global_rect().get_center());await click(page.equip.get_global_rect().get_center())
    check(app.session.request_id==1 and game.battle.step==0,"repeated UI clicks submit once before reply")
    app.set_process(true);await step(1);await ready();page.refresh_data()
    check(game.battle.units[0].equipment[5]==2,"authority equips chosen UID")
    for change in preview.changes:check(game.battle.units[0][change.key]==change.after,"preview matches settled "+change.key)
    check(page.equip.disabled,"settled duplicate UID disabled")
    var after=game.battle.snapshot();var request=app.session.request_id
    check(app.session.submit({"kind":"equip","unit":0,"slot":0,"item":2}),"invalid slot reaches authority for rejection test")
    await ready();await frames();check(game.battle.snapshot()==after and app.session.request_id==request+1,"authority rejects incompatible slot without state change")
    page.choose_slot(0);page.choose_equipment(3);check(not page.equip.disabled,"unowned shared item can be previewed")
    app.session.defer_poll=false
    FileAccess.open(folder.path_join("remote-equip"),FileAccess.WRITE).store_string("go")
    await step(2);await settle();page.refresh_data(true)
    check(game.battle.units[2].equipment[0]==3 and page.equip.disabled,"other client ownership update invalidates old choice")
    check(page.body.text.contains("占用"),"owned item refusal visible")
    after=game.battle.snapshot();page.commit_equipment();check(game.battle.snapshot()==after,"stale owned choice cannot steal")
    check(app.session.submit({"kind":"equip","unit":0,"slot":0,"item":3}),"ownership rejection request reaches authority")
    await ready();await frames();check(game.battle.snapshot()==after,"authority rejects duplicate owner UID")
    var generation=app.session.connection_generation;check(app.session.connect_local(port,token),"real reconnect")
    await frames();check(not is_instance_valid(game.hud.modal) and app.session.connection_generation!=generation,"reconnect closes stale actor context")
    await settle();check(game.battle.step==2 and game.battle.snapshot()==after,"reconnect preserves exact settled state")
    await click(game.hud.dock.details_button.get_global_rect().get_center());page=game.hud.modal
    check(is_instance_valid(page) and page.actor_id==game.battle.units[game.selected].id,"fresh details after reconnect")
    await click(page.back.get_global_rect().get_center());await settle()
    check(app.session.submit({"kind":"move","unit":0,"x":4,"y":6}),"legal move ends preparation")
    await step(3)
    while game.presentation_active():await hold(.05)
    await settle();await click(game.hud.dock.details_button.get_global_rect().get_center());page=game.hud.modal
    check(is_instance_valid(page),"combat still permits browsing")
    page.change_tab(3);page.choose_slot(5);page.choose_equipment(0)
    request=app.session.request_id;check(page.equip.disabled and page.body.text.contains("战斗中"),"out-of-preparation visible lock")
    page.commit_equipment();check(app.session.request_id==request and game.battle.step==3,"locked UI sends no command")
    FileAccess.open(folder.path_join("finish"),FileAccess.WRITE).store_string("go")
    for i in range(300):
        if FileAccess.file_exists(folder.path_join("observer.json")):break
        await hold(.02)
    check(FileAccess.file_exists(folder.path_join("observer.json")),"independent observer completed")
    var observer=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("observer.json")))
    check(observer.hash==game.battle.state_hash(),"three-process exact state hash agreement")
    # Observer IPC JSON parses all numbers as floats; normalize the driver identically.
    check(observer.inventory==JSON.parse_string(JSON.stringify(game.battle.inventory)),"shared inventory normalized JSON agreement")
    print("NETWORK_CHARACTER_DETAILS checks=",checks," failures=0 real_poll=true real_reconnect=true")
    app.session.transport.shutdown();quit()
