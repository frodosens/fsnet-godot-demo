extends SceneTree
const Runtime=preload("res://logic/runtime.gd")
const Content=preload("res://logic/content.gd")
var checks=0
var failures=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():
    var data=Content.default_content()
    for i in range(3,6):data.units[i].controller="player"
    data.units[3].x=3;data.units[3].y=5
    var items=Runtime.new(data)
    check(items.apply_command({"kind":"attack","unit":3,"target":0,"step":1}),"fixture damage uses legal pipeline")
    var wounded=items.units[0].hp
    check(items.apply_command({"kind":"item","consumable":"bandage","unit":0,"target":0,"step":2}) and items.units[0].hp>wounded and items.supplies[0]==1,"consumable heals and decrements shared supply")
    var saved=items.snapshot();var clone=Runtime.new(data)
    check(clone.restore(saved) and clone.state_hash()==items.state_hash(),"consumable supply restores exactly")
    check(not items.apply_command({"kind":"item","consumable":"bandage","unit":0,"target":0,"step":3}) and items.snapshot()==saved,"item uses action budget")
    check(not items.apply_command({"kind":"ability","ability":"healing_draught","unit":1,"target":0,"step":3}) and items.snapshot()==saved,"cannot cast item ability without consuming item")
    data.units[2].controller="ai";data.units[2].policy="support";data.units[2].abilities=["attack","rally"];data.units[2].skill_id="rally"
    data.abilities[1].target="ally";data.abilities[1].reach_bonus=3
    var support=Runtime.new(data);support.apply_command({"kind":"attack","unit":3,"target":0,"step":1});var before=support.units[0].hp
    check(support.apply_command({"kind":"end_turn","step":2}) and support.units[0].hp>before,"friendly support AI heals through ability pipeline")
    data=Content.default_content();data.units[3].policy="defensive";data.units[3].leash=1
    for i in [4,5]:data.units[i].controller="player"
    var guard=Runtime.new(data);var position=guard.units[3].pos
    check(guard.apply_command({"kind":"end_turn","step":1}) and guard.units[3].pos==position,"defensive AI stays at anchor when threats outside leash")
    data=Content.default_content();data.units[0].controller="ai";data.units[0].policy="escort";data.units[0].escort="finn";data.units[0].x=0;data.units[0].y=7
    for i in range(3,6):data.units[i].controller="player"
    var escort=Runtime.new(data)
    var distance=absi(escort.units[0].x-escort.units[1].x)+absi(escort.units[0].y-escort.units[1].y)
    check(escort.apply_command({"kind":"end_turn","step":1}) and absi(escort.units[0].x-escort.units[1].x)+absi(escort.units[0].y-escort.units[1].y)<distance,"escort AI closes toward referenced ally")
    var replay=Runtime.new(data);replay.apply_command({"kind":"end_turn","step":1})
    check(escort.state_hash()==replay.state_hash(),"policy replay deterministic")
    data.units[0].escort="missing"
    check(not Content.validate(data).is_empty(),"invalid escort reference rejected")
    print("ITEM_AI_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
