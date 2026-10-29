extends "res://tests/support/test_case.gd"
const Runtime=preload("res://logic/runtime.gd")
const Content=preload("res://logic/content.gd")
const Authority=preload("res://logic/authority.gd")
func _initialize():
    var data=Content.default_content()
    data.units[0].controller="ai";data.units[0].faction="crew"
    data.units[3].x=3;data.units[3].y=5;data.units[3].faction="guards"
    check(Content.validate(data).is_empty(),"friendly AI content admitted")
    var a=Runtime.new(data);var b=Runtime.new(data);var c=Runtime.new(data)
    var before=a.snapshot()
    check(not a.apply_command({"kind":"attack","actor_id":"mara","target":3,"step":1}) and a.snapshot()==before,"client cannot command friendly AI")
    check(not a.apply_command({"kind":"move","actor_id":"missing","x":2,"y":6,"step":1}) and a.snapshot()==before,"unknown stable actor atomic rejection")
    var command={"kind":"end_turn","step":1}
    for vm in [a,b,c]:check(vm.apply_command(command),"AI phase accepted")
    check(a.units[3].hp<6,"friendly AI uses attack pipeline against enemy faction")
    check(a.state_hash()==b.state_hash() and b.state_hash()==c.state_hash(),"three VMs agree after shared AI phase")
    check(b.restore(a.snapshot()) and b.state_hash()==a.state_hash(),"controller content and snapshot roundtrip")
    var ordinary=Runtime.new()
    check(ordinary.apply_command({"kind":"move","actor_id":"mara","x":3,"y":5,"step":1}),"stable actor ID command")
    var stable=ordinary.snapshot()
    check(not ordinary.apply_command({"kind":"move","actor_id":"finn","unit":0,"x":4,"y":5,"step":2}) and ordinary.snapshot()==stable,"conflicting legacy index rejected")
    check(Authority.command_from_json({"kind":"move","actor_id":"mara","x":3,"y":5,"step":1}).get("actor_id")=="mara","authority preserves stable actor ID")
    check(Runtime.rule_source().contains("run_ai_phase") and not Runtime.rule_source().contains("-- @module"),"full fixed module source linked into hashed rules")
    print("RULE_MODULE_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
