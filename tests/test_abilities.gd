extends "res://tests/support/test_case.gd"
const Runtime=preload("res://logic/runtime.gd")
const Content=preload("res://logic/content.gd")
func _initialize():
    var data=Content.default_content();data.units[3].x=5;data.units[3].y=5
    var a=Runtime.new(data);var b=Runtime.new(data)
    var initial=a.snapshot()
    check(not a.apply_command({"kind":"ability","ability":"missing","unit":2,"target":3,"step":1}) and a.snapshot()==initial,"unknown ability atomic rejection")
    check(a.apply_command({"kind":"ability","ability":"focus_bolt","actor_id":"neri","target_id":"oren","step":1}),"stationary focus spell")
    check(a.units[2].mp==4 and a.units[2].cooldowns[4]==2,"MP and cooldown consumed")
    check(b.restore(a.snapshot()) and a.state_hash()==b.state_hash(),"cooldown charges snapshot roundtrip")
    a.apply_command({"kind":"end_turn","step":2})
    var cooled=a.snapshot()
    check(not a.apply_command({"kind":"ability","ability":"focus_bolt","unit":2,"target":3,"step":3}) and a.snapshot()==cooled,"cooldown cannot be bypassed")
    var moving=Runtime.new(data)
    check(moving.apply_command({"kind":"move","unit":2,"x":6,"y":6,"step":1}),"mage moves")
    var moved=moving.snapshot()
    check(not moving.apply_command({"kind":"ability","ability":"focus_bolt","unit":2,"target":3,"step":2}) and moving.snapshot()==moved,"stationary requirement rejects moved caster")
    check(moving.apply_command({"kind":"skill","unit":2,"target":3,"step":2}),"existing mobile ember unchanged")
    data.abilities[1].target="ally";data.abilities[1].reach_bonus=3
    var healer=Runtime.new(data)
    check(healer.apply_command({"kind":"skill","unit":0,"target":1,"step":1}),"data changes self heal to legal friendly targeting")
    data.abilities[1].effects[0].op="execute_lua"
    check(not Content.validate(data).is_empty(),"arbitrary effect code rejected")
    var blocked_data=Content.default_content();blocked_data.units[3].x=5;blocked_data.units[3].y=4;blocked_data.terrain[5]="GGGGGXGGGG"
    var blocked=Runtime.new(blocked_data);var blocked_state=blocked.snapshot()
    check(not blocked.apply_command({"kind":"ability","ability":"focus_bolt","unit":2,"target":3,"step":1}) and blocked.snapshot()==blocked_state,"solid terrain blocks sight before MP or RNG consumption")
    print("ABILITY_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
