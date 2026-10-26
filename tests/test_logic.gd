extends SceneTree
const Runtime=preload("res://logic/runtime.gd")
const Authority=preload("res://logic/authority.gd")
const Session=preload("res://logic/session.gd")
var checks=0
var failures=0
func check(value,label):
    checks+=1
    if not value: failures+=1;printerr("FAIL: ",label)

func _initialize():
    var a=Runtime.new()
    var b=Runtime.new()
    var c=Runtime.new()
    check(a.units.size()==6,"GDScript -> GDExtension -> Lua state")
    check(a.state_hash()==b.state_hash() and b.state_hash()==c.state_hash(),"three fresh VMs")
    var initial=a.snapshot()
    for cmd in [{"step":1,"kind":"move","unit":0,"x":0,"y":3},
                {"step":1,"kind":"move","unit":0,"x":4,"y":6},
                {"step":2,"kind":"end_turn"},{"step":1,"kind":"attack","unit":0,"target":3},
                {"step":1,"kind":"attack","unit":0,"target":1}]:
        check(not a.apply_command(cmd) and a.snapshot()==initial,"illegal command atomic rejection")
    check(a.apply_command({"step":1,"kind":"move","unit":0,"x":3,"y":5}),"reachable move")
    var after=a.snapshot()
    check(not a.apply_command({"step":2,"kind":"move","unit":0,"x":3,"y":6}) and a.snapshot()==after,"one move per round")
    check(a.apply_command({"step":2,"kind":"skill","unit":0,"target":0}),"knight skill")
    check(a.apply_command({"step":3,"kind":"end_turn"}),"enemy turn")
    check(not a.apply_command({"step":4,"kind":"skill","unit":0,"target":0}),"skill once per battle")
    check(b.restore(a.snapshot()) and a.state_hash()==b.state_hash(),"snapshot roundtrip")
    for raw in ["",a.snapshot()+",0","1,0,1,1,2",a.snapshot().replace(",",",,"),"0"+initial]:
        var previous=b.snapshot()
        check(not b.restore(raw) and b.snapshot()==previous,"malformed snapshot atomic rejection")
    var authority=Authority.new()
    var replica=Session.new()
    var second=Session.new()
    var id=0
    # Use deterministic greedy actions only as a test driver; rules still live in Lua.
    for turn in range(30):
        if authority.logic.outcome!="playing": break
        for index in range(3):
            var logic=authority.logic
            if not logic.usable(index): continue
            var unit=logic.units[index]
            var target=nearest(logic,index)
            if target<0: continue
            var best=unit.pos
            for pos in logic.reachable(index):
                if distance(pos,logic.units[target].pos)<distance(best,logic.units[target].pos):best=pos
            if best!=unit.pos:
                id+=1
                issue(authority,replica,second,id,{"kind":"move","unit":index,"x":best.x,"y":best.y})
            target=nearest(authority.logic,index)
            if target>=0:
                id+=1
                issue(authority,replica,second,id,{"kind":"skill" if index>0 and authority.logic.units[index].skill else "attack","unit":index,"target":target})
        id+=1
        issue(authority,replica,second,id,{"kind":"end_turn"})
    check(authority.logic.outcome!="playing","complete battle terminates")
    print("BATTLE_RESULT outcome=",authority.logic.outcome," step=",authority.logic.step," hash=",authority.logic.state_hash())
    # Reconnect from a fresh VM, then replay a checkpoint and its tail.
    var reconnect=Session.new()
    var reply=authority.handle({"rules":authority.logic.rules_hash,"content":authority.logic.content_hash,"client":"reconnect-client"})
    check(reconnect.synchronize(reply) and reconnect.logic.state_hash()==authority.logic.state_hash(),"snapshot + tail reconnect")
    var broken=reply.duplicate(true)
    broken.hash="bad"
    var previous=reconnect.logic.state_hash()
    check(not reconnect.synchronize(broken) and reconnect.logic.state_hash()==previous,"hash mismatch fails closed")
    # Defeat path: deliberately pass until the enemy clears the crew.
    var passive=Runtime.new()
    for n in range(1,60):
        if passive.outcome!="playing":break
        check(passive.apply_command({"step":n,"kind":"end_turn"}),"pass turn")
    check(passive.outcome=="defeat","defeat path")
    print("LOGIC_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)

func issue(authority,first,second,id,command):
    command.step=authority.logic.step+1
    var request={"rules":authority.logic.rules_hash,"content":authority.logic.content_hash,"client":"test-client","id":id,"command":command}
    var reply=authority.handle(request)
    check(first.synchronize(reply),"replica A executes authoritative log")
    check(second.synchronize(reply),"replica B executes authoritative log")
    check(first.logic.state_hash()==authority.logic.state_hash() and second.logic.state_hash()==authority.logic.state_hash(),"server + two clients same hash")
    var before=authority.logic.snapshot()
    var duplicate=authority.handle(request)
    check(duplicate.reason=="duplicate" and authority.logic.snapshot()==before,"duplicate does not execute twice")

func distance(a,b): return absi(a.x-b.x)+absi(a.y-b.y)
func nearest(logic,index):
    var best=-1
    for i in range(3,6):
        if logic.units[i].hp>0 and (best<0 or distance(logic.units[index].pos,logic.units[i].pos)<distance(logic.units[index].pos,logic.units[best].pos)):best=i
    return best
