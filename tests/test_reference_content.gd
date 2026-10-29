extends "res://tests/support/test_case.gd"
const Content=preload("res://logic/content.gd")
const Runtime=preload("res://logic/runtime.gd")
const Authority=preload("res://logic/authority.gd")
const Session=preload("res://logic/session.gd")
var request_id=0
func _initialize():call_deferred("run")
func distance(a,b):return absi(a.x-b.x)+absi(a.y-b.y)
func nearest(logic,index):
    var best=-1
    for i in range(3,6):
        if logic.units[i].hp>0 and (best<0 or distance(logic.units[index].pos,logic.units[i].pos)<distance(logic.units[index].pos,logic.units[best].pos)):best=i
    return best
func issue(authority,replicas,command):
    request_id+=1;command.step=authority.logic.step+1
    var reply=authority.handle({"rules":authority.logic.rules_hash,"content":authority.logic.content_hash,"client":"reference-test","id":request_id,"command":command})
    for replica in replicas:check(replica.synchronize(reply) and replica.logic.state_hash()==authority.logic.state_hash(),"same ordered commands on all three VMs")
func run():
    var data=Content.reference_content();var legacy=Content.default_content()
    check(data.height==9 and legacy.height==8 and data.id!=legacy.id,"new content does not overwrite old fixture")
    check(data.story==legacy.story and data.victory==legacy.victory and data.defeat==legacy.defeat,"story and objectives preserved")
    check(not Content.write_mod(data).is_empty(),"reserved builtin ID cannot be overwritten by Mod")
    var logic=Runtime.new(data);var before=logic.snapshot()
    check(logic.path_to(0,Vector2i(4,4)).size()==4 and logic.snapshot()==before,"three-step landing in middle of bridge is read-only")
    check(logic.path_to(0,Vector2i(3,4)).is_empty(),"deep visual water still non-traversable")
    var app=root.get_node("App");app.save_root="user://reference_test_"+str(Time.get_ticks_usec());app.new_game(data);app.next_story();app.advance_story(false)
    check(app.save_slot("slot1")=="","reference save writes embedded content")
    var saved_hash=app.session.logic.state_hash();app.new_game(legacy)
    check(app.load_slot("slot1") and app.session.logic.content.id==data.id and app.session.logic.state_hash()==saved_hash and app.next_story().index==2,"load restores correct map, RNG and local story cursor")
    var authority=Authority.new(data);var replicas=[]
    for i in range(2):
        var replica=Session.new();replica.logic=Runtime.new(data);replicas.append(replica)
    for turn in range(35):
        if authority.logic.outcome!="playing":break
        for actor in range(3):
            var active=authority.logic
            if not active.usable(actor):continue
            var target=nearest(active,actor)
            if target<0:continue
            var best=active.units[actor].pos
            for pos in active.reachable(actor):
                if distance(pos,active.units[target].pos)<distance(best,active.units[target].pos):best=pos
            if best!=active.units[actor].pos:issue(authority,replicas,{"kind":"move","unit":actor,"x":best.x,"y":best.y})
            target=nearest(authority.logic,actor)
            if target>=0:issue(authority,replicas,{"kind":"skill" if actor>0 and authority.logic.units[actor].skill else "attack","unit":actor,"target":target})
        issue(authority,replicas,{"kind":"end_turn"})
    check(authority.logic.outcome!="playing","AI battle reaches terminal objective on longer bridge")
    var rejoin=Session.new();rejoin.logic=Runtime.new(data)
    var reply=authority.handle({"rules":authority.logic.rules_hash,"content":authority.logic.content_hash,"client":"reference-rejoin"})
    check(rejoin.synchronize(reply) and rejoin.logic.state_hash()==authority.logic.state_hash(),"reference snapshot and command-tail replay")
    var passive=Runtime.new(data)
    for step in range(1,65):
        if passive.outcome!="playing":break
        passive.apply_command({"kind":"end_turn","step":step})
    check(passive.outcome=="defeat","enemy AI can cross bridge and trigger defeat")
    print("REFERENCE_CONTENT_TESTS checks=",checks," failures=",failures," outcome=",authority.logic.outcome," hash=",authority.logic.state_hash())
    quit(1 if failures else 0)
