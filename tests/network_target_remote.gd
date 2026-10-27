extends SceneTree
var session=preload("res://logic/session.gd").new()
var sent=false
var folder=OS.get_environment("AMBER_CONFIRM_CONTROL")
func _initialize():
    session.offline(preload("res://logic/content.gd").reference_content())
    assert(session.connect_local(int(OS.get_environment("AMBER_TEST_PORT")),OS.get_environment("AMBER_TOKEN")))
func _process(delta):
    session.tick(delta)
    if not sent and FileAccess.file_exists(folder.path_join("remote-turn")) and session.ready and not session.pending:
        sent=session.submit({"kind":"end_turn"})
    if FileAccess.file_exists(folder.path_join("stop")):
        print("NETWORK_TARGET_REMOTE sent=",sent," step=",session.logic.step);session.transport.shutdown();quit(0 if sent and session.logic.step==2 else 1)
    return false
