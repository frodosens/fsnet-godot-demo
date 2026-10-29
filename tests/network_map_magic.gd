extends SceneTree
var app
var g
var role='driver'
var folder=OS.get_environment('AMBER_MAGIC_CONTROL')
func _initialize():call_deferred('run')
func check(ok,label):
    if not ok:printerr('FAIL: ',label);quit(1)
    assert(ok,label)
func hold(seconds):await create_timer(seconds).timeout
func ready():
    for i in range(300):
        if app.session.ready and not app.session.pending:return
        await hold(.02)
    check(false,'connection timeout')
func run():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with('--role='):role=arg.trim_prefix('--role=')
    app=root.get_node('App');app.sfx_enabled=false
    var data=load('res://logic/content.gd').from_file(OS.get_environment('AMBER_MOD')).data
    var port=int(OS.get_environment('AMBER_TEST_PORT'));var token=OS.get_environment('AMBER_TOKEN')
    check(app.start_room(false,port,token,data),'fsnet connect')
    await ready();change_scene_to_file('res://main.tscn');await process_frame;await process_frame;g=current_scene
    while not app.next_story().is_empty():app.advance_story(true)
    g.refresh();g.map_magic.set_process(false)
    FileAccess.open(folder.path_join(role+'-ready'),FileAccess.WRITE).store_string('ready')
    if role=='driver':
        for i in range(300):
            if FileAccess.file_exists(folder.path_join('observer-ready')):break
            await hold(.02)
        await ready();check(app.session.submit({'kind':'ability','ability':'focus_bolt','unit':2,'target':3}),'network spell submit')
    for i in range(300):
        if app.session.logic.step==1:break
        await hold(.02)
    check(app.session.logic.step==1,'actual authoritative spell received');g.battle=app.session.logic;g.refresh()
    check(g.map_magic.active and not g.cutin.active,'network event routed into map timeline')
    var event=g.event_sequence.current.duplicate(true);var truth=g.battle.snapshot()
    check(event.ability=='focus_bolt' and g.map_magic.impact_count==0,'network ability metadata and no early impact')
    g.map_magic._process(.4)
    check(g.event_sequence.health[event.target]==event.hp+event.damage,'before-impact HP preserved')
    var instance=app.session.logic.get_instance_id()
    await hold(.5)
    check(app.session.logic.get_instance_id()!=instance and g.map_magic.elapsed==.4,'ordinary network VM replacement preserves timeline')
    if role=='driver':
        check(app.session.connect_local(port,token),'actual reconnect during spell')
        await ready();await hold(.1)
        check(g.map_magic.active and g.map_magic.elapsed==.4,'same-step reconnect does not replay spell')
    g.map_magic._process(.23)
    check(g.event_sequence.health[event.target]==event.hp and g.map_magic.impact_count==1,'one network spell impact')
    g.map_magic._process(.8);await process_frame;await process_frame
    check(not g.presentation_active() and g.battle.snapshot()==truth,'network display settles without changing state')
    await hold(.3);check(g.map_magic.impact_count==1,'poll replay does not repeat impact')
    print('MAP_MAGIC_NETWORK_RESULT ',JSON.stringify({'role':role,'hash':g.battle.state_hash(),'step':g.battle.step,'impacts':g.map_magic.impact_count,'reconnected':role=='driver'}))
    app.session.transport.shutdown();quit()
