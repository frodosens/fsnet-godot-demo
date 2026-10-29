extends SceneTree
var session=Session.new()
var sent=false
var folder=OS.get_environment("AMBER_DETAILS_CONTROL")
func _initialize():
    session.offline(Content.reference_content())
    assert(session.connect_local(int(OS.get_environment("AMBER_TEST_PORT")),OS.get_environment("AMBER_TOKEN")))
func _process(delta):
    session.tick(delta)
    if not sent and FileAccess.file_exists(folder.path_join("remote-equip")) and session.ready and not session.pending:
        sent=session.submit({"kind":"equip","unit":2,"slot":0,"item":3})
    if FileAccess.file_exists(folder.path_join("finish")) and session.logic.step==3:
        FileAccess.open(folder.path_join("observer.json"),FileAccess.WRITE).store_string(JSON.stringify({"hash":session.logic.state_hash(),"step":session.logic.step,"inventory":session.logic.inventory,"equipment":session.logic.units[2].equipment}))
        print("NETWORK_DETAILS_REMOTE step=",session.logic.step," sent=",sent);session.transport.shutdown();quit(0 if sent else 1)
    return false
