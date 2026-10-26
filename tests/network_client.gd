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
var extended=false
var content={}
func _initialize():
    var port=27840
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
        if arg.begins_with("--port="):port=int(arg.trim_prefix("--port="))
    extended="--extended" in OS.get_cmdline_user_args()
    var mod_path=OS.get_environment("AMBER_MOD")
    if not mod_path.is_empty():
        var loaded=Runtime.Content.from_file(mod_path)
        assert(loaded.error.is_empty());content=loaded.data
    session=Session.new();session.logic=Runtime.new(content)
    if not session.connect_local(port,OS.get_environment("AMBER_TOKEN")):quit(1)
func _process(delta):
    elapsed+=delta
    if elapsed>15:printerr("NETWORK_TIMEOUT role=",role," status=",session.status);quit(1);return false
    if disconnected and not resumed:
        if elapsed<reconnect_at:return false
        session.logic=Runtime.new(content)
        session.connect_local(session.port,session.token)
        resumed=true
    session.tick(delta)
    if session.failed:printerr(session.status);quit(1);return false
    if session.pending or not session.status.begins_with("Online"):return false
    if extended:
        extended_step()
        return false
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

func extended_step():
    var step=session.logic.step
    if role=="driver":
        match step:
            0:session.submit({"kind":"equip","unit":0,"slot":5,"item":2})
            1:session.submit({"kind":"equip","unit":2,"slot":0,"item":3})
            2:session.submit({"kind":"move","unit":0,"x":3,"y":5})
            3:session.submit({"kind":"move","unit":0,"x":3,"y":6})
            4:session.submit({"kind":"end_turn"})
            5:
                if not disconnected:
                    session.transport.shutdown();disconnected=true;reconnect_at=elapsed+0.7
                    print("CLIENT_DISCONNECTED after_step=5 gear_and_extra_move=true")
            6:
                if resumed:
                    var caster=session.logic.units[2]
                    for i in range(3,session.logic.units.size()):
                        var target=session.logic.units[i]
                        if target.hp>0 and absi(caster.x-target.x)+absi(caster.y-target.y)<=caster.reach+1:
                            session.submit({"kind":"ability","ability":"focus_bolt","unit":2,"target":i});break
    elif step==5:session.submit({"kind":"item","consumable":"bandage","unit":0,"target":0})
    if step==7 and (role!="driver" or resumed):
        if done_at==0.0:done_at=elapsed+0.4
        if elapsed>=done_at:
            assert(session.logic.units[0].move_actions==2 and session.logic.units[2].mobile_cast and session.logic.supplies[0]==1)
            print("NETWORK_RESULT ",JSON.stringify({"role":role,"step":step,"hash":session.logic.state_hash(),"reconnected":resumed,"extended":true}))
            session.transport.shutdown();quit(0)
