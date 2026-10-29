extends SceneTree
var session
var elapsed=0.0
func _initialize():
    var port=0
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--port="):port=int(arg.trim_prefix("--port="))
    var data=preload("res://logic/content.gd").from_file(OS.get_environment("AMBER_MOD")).data
    data.units[0].hp+=1 # Same template ID, different expanded revision.
    session=preload("res://logic/session.gd").new();session.logic=preload("res://logic/runtime.gd").new(data)
    assert(session.connect_local(port,OS.get_environment("AMBER_TOKEN")))
func _process(delta):
    elapsed+=delta;session.tick(delta)
    if session.failed:
        assert(session.status=="Protocol/rules mismatch")
        print("UNIT_REVISION_REJECTED real_transport=true step=",session.logic.step)
        session.transport.shutdown();quit();return false
    if elapsed>5:push_error("revision mismatch was not rejected");quit(1)
    return false
