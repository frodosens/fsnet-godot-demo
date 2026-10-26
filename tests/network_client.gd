extends SceneTree
const Session=preload("res://logic/session.gd")
const Runtime=preload("res://logic/runtime.gd")
var session
var role="driver"
var elapsed=0.0
var disconnected=false
var resumed=false
var reconnect_at=0.0
var done_at=0.0
func _initialize():
    var port=27840
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
        if arg.begins_with("--port="):port=int(arg.trim_prefix("--port="))
    session=Session.new()
    if not session.connect_local(port,OS.get_environment("AMBER_TOKEN")):quit(1)
func _process(delta):
    elapsed+=delta
    if elapsed>15:printerr("NETWORK_TIMEOUT role=",role," status=",session.status);quit(1);return false
    if disconnected and not resumed:
        if elapsed<reconnect_at:return false
        session.logic=Runtime.new()
        session.connect_local(session.port,session.token)
        resumed=true
    session.tick(delta)
    if session.failed:printerr(session.status);quit(1);return false
    if session.pending or not session.status.begins_with("Online"):return false
    if role=="driver":
        if session.logic.step==0:session.submit({"kind":"move","unit":0,"x":3,"y":5})
        elif session.logic.step==1:session.submit({"kind":"end_turn"})
        elif session.logic.step==2 and not disconnected:
            session.transport.shutdown();disconnected=true;reconnect_at=elapsed+0.7
            print("CLIENT_DISCONNECTED after_step=2")
    elif session.logic.step==2:
        session.submit({"kind":"move","unit":1,"x":4,"y":5})
    if session.logic.step==3 and (role!="driver" or resumed):
        if done_at==0.0:done_at=elapsed+0.4
        if elapsed>=done_at:
            print("NETWORK_RESULT ",JSON.stringify({"role":role,"step":session.logic.step,"hash":session.logic.state_hash(),"reconnected":resumed}))
            session.transport.shutdown();quit(0)
    return false
func _finalize():
    if session and session.transport:session.transport.shutdown()
