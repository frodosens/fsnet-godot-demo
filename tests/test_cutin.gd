extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    var data=Content.default_content();data.units[3].x=3;data.units[3].y=5
    var logic=Runtime.new(data)
    check(logic.apply_command({"kind":"attack","actor_id":"mara","target":3,"step":1}),"actual shared rule attack")
    check(logic.events.size()==1 and logic.events[0].damage>0,"settled attack emits damage event")
    var state=logic.snapshot()
    var cutin=load("res://ui/battle_cutin.gd").new();root.add_child(cutin)
    cutin.consume(logic.step,logic.events)
    check(cutin.active,"matching sword slice plays")
    cutin.draw_tick(11);cutin.finish()
    check(not cutin.active and logic.snapshot()==state,"skip never changes settled state")
    cutin.consume(logic.step,logic.events)
    check(not cutin.active,"same step does not replay animation")
    data.victory={"kind":"all","children":[{"kind":"survive","round":2},{"kind":"reach","unit":"mara","x":3,"y":6}]}
    check(Content.validate(data).is_empty(),"bounded composite objectives admitted")
    var objective=Runtime.new(data)
    check(objective.apply_command({"kind":"end_turn","step":1}) and objective.outcome=="victory","survive and reach evaluated after AI phase")
    check(objective.restore(objective.snapshot()),"composite terminal snapshot roundtrip")
    data.defeat={"kind":"survive","round":2}
    var tie=Runtime.new(data);tie.apply_command({"kind":"end_turn","step":1})
    check(tie.outcome=="defeat","simultaneous objectives choose defeat")
    var terminal=tie.snapshot()
    check(not tie.apply_command({"kind":"end_turn","step":2}) and tie.snapshot()==terminal,"terminal commands rejected")
    print("CUTIN_OBJECTIVE_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
