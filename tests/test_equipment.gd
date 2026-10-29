extends "res://tests/support/test_case.gd"
func _initialize():
    var data=Content.default_content();data.units[3].x=5;data.units[3].y=5
    var a=Runtime.new(data);var b=Runtime.new(data);var c=Runtime.new(data)
    var commands=[{"kind":"equip","unit":0,"slot":5,"item":2,"step":1},{"kind":"equip","unit":2,"slot":0,"item":3,"step":2}]
    for command in commands:
        for vm in [a,b,c]:check(vm.apply_command(command),"same authoritative equip command")
    check(a.units[0].move_actions==2 and a.units[2].mobile_cast,"real special capabilities derived")
    check(a.state_hash()==b.state_hash() and b.state_hash()==c.state_hash(),"three VM gear agreement")
    check(b.restore(a.snapshot()) and b.state_hash()==a.state_hash(),"gear UID affixes and capabilities restore")
    check(a.apply_command({"kind":"move","unit":0,"x":3,"y":5,"step":3}),"first move")
    check(a.apply_command({"kind":"move","unit":0,"x":3,"y":6,"step":4}),"extra move action, unchanged distance")
    var exhausted=a.snapshot()
    check(not a.apply_command({"kind":"move","unit":0,"x":2,"y":6,"step":5}) and a.snapshot()==exhausted,"move budget exhausted")
    check(not a.apply_command({"kind":"equip","unit":0,"slot":5,"item":0,"step":5}) and a.snapshot()==exhausted,"combat unequip cannot refresh budget")
    check(a.apply_command({"kind":"move","unit":2,"x":6,"y":6,"step":5}),"equipped mage moves")
    check(a.apply_command({"kind":"ability","ability":"focus_bolt","unit":2,"target":3,"step":6}),"mobile_cast actually removes stationary spell restriction")
    var after=a.snapshot()
    check(not a.apply_command({"kind":"ability","ability":"focus_bolt","unit":2,"target":3,"step":6}) and a.snapshot()==after,"duplicate command consumes no extra charge or RNG")
    check(c.restore(after) and c.state_hash()==a.state_hash(),"used movement MP cooldown and gear survive restore")
    var set_case=Runtime.new()
    set_case.apply_command({"kind":"equip","unit":0,"slot":5,"item":2,"step":1})
    check(set_case.apply_command({"kind":"equip","unit":0,"slot":6,"item":4,"step":2}) and set_case.units[0].max_hp==14 and set_case.units[0].damage==4,"two-piece set applies derived bonuses")
    var injured_hp=set_case.units[0].hp
    set_case.apply_command({"kind":"equip","unit":0,"slot":6,"item":0,"step":3})
    set_case.apply_command({"kind":"equip","unit":0,"slot":6,"item":4,"step":4})
    check(set_case.units[0].hp==injured_hp,"preparation re-equip does not heal")
    var invalid=Runtime.new();var initial=invalid.snapshot()
    check(not invalid.apply_command({"kind":"equip","unit":0,"slot":0,"item":2,"step":1}) and invalid.snapshot()==initial,"wrong slot rejected atomically")
    data.victory={"kind":"survive","round":2}
    var win=Runtime.new(data);var replay=Runtime.new(data)
    var turn={"kind":"end_turn","step":1}
    check(win.apply_command(turn) and replay.apply_command(turn) and win.inventory.size()==5,"deterministic victory drop generated")
    check(win.state_hash()==replay.state_hash() and replay.restore(win.snapshot()) and win.state_hash()==replay.state_hash(),"drop seed UID rolled affixes replay and restore")
    var terminal=win.snapshot()
    check(not win.apply_command(turn) and win.snapshot()==terminal,"duplicate terminal command cannot reroll reward")
    print("EQUIPMENT_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
