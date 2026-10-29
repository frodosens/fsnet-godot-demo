extends "res://tests/support/test_case.gd"
const Content=preload("res://logic/content.gd")
const Runtime=preload("res://logic/runtime.gd")
func _initialize():call_deferred("run")
func run():
    var data=Content.default_content();data.units[3].x=3;data.units[3].y=5;data.units[3].hp=100
    data.abilities[0].crit_chance=100;data.abilities[0].crit_multiplier=200
    var logic=Runtime.new(data);var clone=Runtime.new(data);var before=logic.snapshot()
    for i in range(20):
        var path=logic.path_to(0,Vector2i(2,6))
        check(path.size()==2 and logic.snapshot()==before,"BFS preview query does not consume state/RNG")
    check(logic.path_to(0,Vector2i(0,3)).is_empty(),"unreachable hover has no invented path")
    check(not logic.apply_command({"kind":"attack","unit":0,"target":0,"step":1}) and logic.snapshot()==before,"invalid critical command consumes no RNG")
    var prediction=logic.preview_action({"kind":"attack","unit":0,"target":3})
    check(prediction.legal and prediction.crit_chance==100 and logic.snapshot()==before,"damage forecast validates without consuming RNG")
    check(not logic.preview_action({"kind":"attack","unit":0,"target":0}).legal and logic.snapshot()==before,"illegal forecast does not mutate state")
    check(logic.apply_command({"kind":"attack","unit":0,"target":3,"step":1}),"critical attack accepted")
    check(logic.events[0].damage>=prediction.critical_low and logic.events[0].damage<=prediction.critical_high,"actual critical fits advertised integer interval")
    clone.apply_command({"kind":"attack","unit":0,"target":3,"step":1})
    check(logic.events[0].is_critical and logic.state_hash()==clone.state_hash(),"critical event comes from deterministic rule RNG")
    var normal=data.duplicate(true);normal.abilities[0].crit_chance=0;var ordinary=Runtime.new(normal);ordinary.apply_command({"kind":"attack","unit":0,"target":3,"step":1})
    check(logic.events[0].damage==ordinary.events[0].damage*2,"integer critical multiplier affects real damage")
    check(clone.restore(logic.snapshot()) and clone.state_hash()==logic.state_hash(),"critical RNG restores exactly")
    var cutin=load("res://ui/battle_cutin.gd").new();root.add_child(cutin);cutin.set_process(false);cutin.consume(1,logic.events)
    cutin.draw_tick(cutin.hit_tick())
    check(cutin.weapon_screen_point().distance_to(cutin.hurt_screen_point())<0.01,"actual melee tip reaches actual hurt socket at hit tick")
    check(cutin.flash_material.get_shader_parameter("flash_strength")>0 and cutin.damage_label.text.contains("暴击"),"critical contact flashes only victim and shows real critical number")
    cutin.finish()
    check(cutin.arena.position==cutin.layout_origin and cutin.flash_material.get_shader_parameter("flash_strength")==0 and not cutin.damage_label.visible,"skip resets camera/flash/number")
    cutin.consume(1,logic.events);check(not cutin.active,"replayed step never repeats hit feedback")
    for id in ["finn","neri"]:
        var shot=Runtime.new(data);var command={"kind":"attack","actor_id":id,"target_id":"oren","step":1}
        if id=="neri":command.kind="ability";command.ability="focus_bolt"
        shot.apply_command(command);cutin.last_seen_step=-1;cutin.consume(1,shot.events);cutin.draw_tick(cutin.hit_tick())
        check(cutin.projectile.visible and cutin.projectile_screen_point().distance_to(cutin.hurt_screen_point())<0.01,"projectile actual tip reaches hurt socket before hiding "+id)
        cutin.finish()
    for attacker in [3,4,5]:
        var enemy_data=Content.default_content();enemy_data.units[attacker].x=3;enemy_data.units[attacker].y=5;enemy_data.units[attacker].controller="player"
        var fight=Runtime.new(enemy_data)
        check(fight.apply_command({"kind":"attack","unit":attacker,"target":0,"step":1}),"real enemy attack fixture")
        cutin.last_seen_step=-1;cutin.consume(1,fight.events);cutin.draw_tick(cutin.hit_tick())
        check(cutin.active and cutin.weapon_screen_point().distance_to(cutin.hurt_screen_point())<0.01,"enemy weapon socket reaches ally hit region")
        cutin.feedback_strength=0;cutin.draw_tick(cutin.hit_tick())
        check(cutin.arena.position==cutin.layout_origin and cutin.damage_label.scale==Vector2.ONE and cutin.flash_material.get_shader_parameter("flash_strength")==0,"reduced motion removes shake flash and number scaling")
        cutin.finish();cutin.feedback_strength=1
    var mixed=Content.default_content();mixed.units[3].x=3;mixed.units[3].y=5;mixed.units[3].hp=4
    mixed.abilities[0].crit_chance=50;mixed.abilities[0].effects=[{"op":"damage","value":0,"radius":0},{"op":"heal","value":4,"radius":0},{"op":"damage","value":0,"radius":0}]
    var branches=Runtime.new(mixed);var mixed_before=branches.snapshot();var bounds=branches.preview_action({"kind":"attack","unit":0,"target":3})
    check(bounds.legal and bounds.high>=7 and branches.snapshot()==mixed_before,"mixed damage/heal/crit preview considers survival branches without RNG")
    branches.apply_command({"kind":"attack","unit":0,"target":3,"step":1});var actual=0
    for emitted in branches.events:
        if emitted.kind=="attack":actual+=emitted.damage
    check(actual>=bounds.low and actual<=bounds.high,"mixed actual amounts stay in predicted interval")
    cutin.consume(99,[logic.events[0],logic.events[0]])
    cutin.draw_tick(cutin.hit_tick())
    check(cutin.damage_label.position.y<cutin.defender.position.y,"digits sit above the defender instead of masking contact")
    check(cutin.pending_events.size()==1,"multi-hit feedback queues a single visible number group")
    cutin.play_next();check(cutin.pending_events.is_empty() and not cutin.damage_label.visible,"next hit clears previous number before contact")
    cutin.finish()
    print("CONTACT_PATH_CRIT_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
