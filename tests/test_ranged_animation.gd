extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    var cutin=load("res://ui/battle_cutin.gd").new();root.add_child(cutin);cutin.set_process(false)
    for spec in [["finn","attack"],["neri","focus_bolt"],["neri","attack"]]:
        var id=spec[0]
        var data=Content.default_content();data.units[3].x=3;data.units[3].y=5
        if spec==["neri","attack"]:data.units[3].x=5
        var logic=Runtime.new(data)
        var command={"kind":"attack","actor_id":id,"target_id":"oren","step":1}
        if spec[1]!="attack":command.kind="ability";command.ability=spec[1]
        check(logic.apply_command(command),"real ordered "+id+" attack")
        var snapshot=logic.snapshot();cutin.last_seen_step=-1;cutin.consume(1,logic.events)
        check(cutin.active and cutin.actor_sets[id].textures.size()==8,"eight independent manifest frames "+id)
        cutin.draw_tick(11);check(cutin.damage_label.text.is_empty(),"damage hidden before release/impact")
        cutin.draw_tick(12);var first=cutin.projectile.position
        check(cutin.projectile.visible,"projectile separate layer at release")
        cutin.draw_tick(15);check(cutin.projectile.position.x>first.x,"projectile travels toward target")
        cutin.draw_tick(16);check(not cutin.damage_label.text.is_empty(),"impact aligns with hit pose and damage")
        cutin.finish();check(logic.snapshot()==snapshot,"skip leaves rule result unchanged")
        if spec==["neri","attack"]:
            cutin.consume(2,logic.events,logic.units,logic.content,str(logic.units[3].faction))
            check(cutin.active and not cutin.actor_left,"Neri ordinary attack supports opposite viewer side")
            cutin.draw_tick(16)
            check(cutin.attacker.flip_h,"Neri ordinary attack mirrors actor on right")
            check(cutin.projectile_screen_point().distance_to(cutin.hurt_screen_point())<0.01,"mirrored ordinary projectile meets hurt socket")
            cutin.finish();check(logic.snapshot()==snapshot,"mirrored presentation leaves authority unchanged")

    cutin.consume(3,[{"kind":"move","actor":"mara","path":[]}])
    check(not cutin.active,"new nonattack step clears old cutin")
    print("RANGED_ANIMATION_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
