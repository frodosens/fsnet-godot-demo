extends "res://tests/support/test_case.gd"
const C=preload("res://logic/content.gd")
const R=preload("res://logic/runtime.gd")
const F=preload("res://tests/unit_definition_fixture.gd")
func _initialize():
    var d=F.twins();require(C.validate(d)=="","two arbitrary instances one template")
    var a=R.new(d);var b=R.new(d)
    var other=a.units[1].duplicate(true)
    require(a.apply_command({"kind":"equip","actor_id":"custom_guard_0","slot":0,"item":1,"step":1}),"first equipment")
    require(a.units[1]==other,"no shared equipment or derived stat")
    var snapshot=a.snapshot()
    require(not a.apply_command({"kind":"equip","actor_id":"custom_guard_1","slot":0,"item":1,"step":2}) and a.snapshot()==snapshot,"unique item ownership")
    require(a.apply_command({"kind":"move","actor_id":"custom_guard_0","x":2,"y":6,"step":2}),"ID move")
    require(a.units[1]==other,"move only one instance")
    require(not a.apply_command({"kind":"wait","actor_id":"custom_guard_0","unit":1,"step":3}),"conflicting index rejected")
    require(a.apply_command({"kind":"wait","unit":0,"step":3}),"index-only remains accepted")
    require(b.restore(a.snapshot()) and b.units==a.units,"snapshot restores instance configuration")
    var ability=R.new(F.twins());var untouched=ability.units[1].duplicate(true)
    require(ability.apply_command({"kind":"ability","actor_id":"custom_guard_0","ability":"rally","target_id":"custom_guard_0","step":1}),"ability command")
    require(ability.units[1]==untouched and ability.units[0].charges!=ability.units[1].charges,"charges and action state isolated")
    var maximum=F.twins();maximum.width=16;maximum.height=16;maximum.terrain=[]
    for y in 16:maximum.terrain.append("G".repeat(16))
    maximum.unit_definitions=[maximum.unit_definitions[0]];maximum.units=[]
    for i in 16:maximum.units.append({"id":"instance_"+str(i),"template_ref":maximum.unit_definitions[0].id,"x":i,"y":1,"ally":i<8,"controller":"ai","policy":"defensive" if i%2==0 else "offensive","leash":2+i%4})
    require(C.validate(maximum)=="","16 instances one immutable definition")
    var max_runtime=R.new(maximum);require(max_runtime.apply_command({"kind":"end_turn","step":1}),"independent AI policies/anchors within budget")
    maximum.units.append(maximum.units[0].duplicate(true));require(not C.validate(maximum).is_empty(),"17 instances rejected")
    var auth=Authority.new(d)
    var revised=d.duplicate(true);revised.unit_definitions[0].damage+=1
    require(auth.handle({"rules":auth.logic.rules_hash,"content":C.hash_of(revised),"client":"template-revision"}).get("error")=="rules mismatch","template revision cannot join room")
    var app=root.get_node("App");app.new_game(d);var session=app.session
    var invalid=d.duplicate(true);invalid.units[0].template_ref="absent"
    require(not app.new_game(invalid) and app.session==session,"invalid admission cannot discard active session")
    require(app.save_slot("slot3")=="","save expanded content")
    var saved=app.session.logic.snapshot();d.unit_definitions[0].hp+=20
    app.new_game(d);require(app.load_slot("slot3") and app.session.logic.snapshot()==saved,"load uses saved expansion not changed definitions")
    require(R.accepts_saved_rules("72cde9c5e5f4bcfc0e44f59a60439a1702937933b32248fce1c275ab9af09e3c") and not R.accepts_saved_rules("untrusted"),"exact predecessor only")
    print("UNIT_INSTANCE_STATE checks=",checks," failures=",failures);quit(1 if failures else 0)
