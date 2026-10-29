extends "res://tests/support/test_case.gd"
# Real ordered Lua attacks establish both actor roles; pose probes never submit commands.
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.sfx_enabled=false;app.reduced_motion=false
    var cutin=load("res://ui/battle_cutin.gd").new();root.add_child(cutin);cutin.set_process(false)
    var neutral=load("res://assets/battle/mara/00_idle.png")
    var inhale=load("res://assets/battle/mara/idle/01_inhale.png")
    require(cutin.idle_library.errors.is_empty(),"valid clips")
    require(cutin.idle_library.clips.battle.keys()==["mara:right","oren:left","finn:right","neri:right","tessa:right","bram:right","oren:right"],"exact received battle clips")
    var data=Content.reference_content();data.units[3].x=data.units[0].x+1;data.units[3].y=data.units[0].y
    var logic=Runtime.new(data)
    require(logic.apply_command({"kind":"attack","actor_id":"mara","target_id":"oren","step":1}),"real player attack")
    var player_events=logic.events.duplicate(true);var player_units=logic.units.duplicate(true)
    var player_snapshot=logic.snapshot()
    cutin.consume(1,player_events,player_units,data)
    for frame in range(24):
        cutin.draw_tick(frame)
        require(cutin.attacker.texture.resource_path=="res://assets/battle/mara/"+cutin.MARA[cutin.TIMELINE[frame]]+".png","authored attack and settle not overridden")
        require(not cutin.defender.flip_h,"Oren defender uses already-left source")
    require(logic.snapshot()==player_snapshot,"presentation unchanged snapshot")
    require(logic.apply_command({"kind":"end_turn","step":2}),"real following AI turn")
    var enemy_events=logic.events.duplicate(true);var enemy_units=logic.units.duplicate(true);var snapshot=logic.snapshot()
    cutin.consume(2,enemy_events,enemy_units,data)
    require(cutin.event.actor=="oren" and cutin.event.target=="mara","AI attack back, no invented counterattack")
    require(cutin.tick_seconds==0.06 and cutin.release_tick==9,"original duration and impact")
    for t in [0.0,0.31,0.32,0.36,0.419,0.42,0.54,0.78,1.32,1.38]:
        cutin.draw_tick(t/cutin.tick_seconds)
        var expected=inhale if t>=0.32 and t<0.42 else neutral
        if t>=0.54 and t<0.78:expected=cutin.defender_sets.mara.hit
        elif t>=0.78:expected=cutin.defender_sets.mara.recover
        require(cutin.defender.texture==expected,"neutral/inhale/brace/hit/recover at "+str(t))
        require(not cutin.defender.flip_h and not cutin.actor_left,"Mara remains left facing the right-side enemy attacker")
    app.reduced_motion=true;cutin.draw_tick(6)
    require(cutin.defender.texture==neutral,"reduced motion holds neutral")
    app.reduced_motion=false
    # A paused tree freezes the actual cut-in clock and current pose.
    cutin.elapsed=0.36;cutin.draw_tick(6);cutin.set_process(true);paused=true
    await create_timer(0.08,true).timeout
    require(cutin.elapsed==0.36 and cutin.defender.texture==inhale,"pause freezes clock and pose")
    paused=false;cutin.set_process(false)
    # Skip during inhale clears the event; repeated same step does not replay.
    cutin.finish();require(not cutin.active and not cutin.surface.visible,"skip cleanup")
    cutin.consume(2,enemy_events,enemy_units,data);require(not cutin.active,"same step deduplicated")
    for rate in [1.0,2.0,4.0]:
        cutin.last_seen_step=-1;cutin.speed=rate;cutin.consume(2,enemy_events,enemy_units,data)
        var samples=0;var saw_inhale=false;var hits=cutin.impact_play_count
        while cutin.active and samples<400:
            cutin._process(1.0/120.0);samples+=1
            saw_inhale=saw_inhale or cutin.defender.texture==inhale
        require(saw_inhale,"inhale really sampled at speed "+str(rate))
        require(not cutin.active and cutin.impact_play_count==hits+1,"one impact, bounded completion")
        require(logic.snapshot()==snapshot,"speed/skip cannot change Lua state")
    # Consecutive settled events reset pose phase, retaining final recover until next event.
    cutin.last_seen_step=-1;cutin.consume(3,player_events+enemy_events,enemy_units,data)
    cutin.draw_tick(23);require(cutin.attacker.texture.resource_path.ends_with("07_settle_guard.png"),"keep settle")
    cutin.play_next();require(cutin.defender.texture==neutral and cutin.elapsed==0,"next event neutral phase")
    # Death presentation fixture: no new combat rule or damage is synthesized by idle code.
    cutin.event.hp=0;cutin.draw_tick(23)
    require(cutin.defender.texture==cutin.defender_sets.mara.hit and cutin.defender.modulate.a==0,"dead target never returns to idle")
    for id in ["unconfigured-guard"]:
        require(cutin.idle_library.sample("battle",id+":right",.4,neutral,false,id)==neutral,"single-frame fallback "+id)
    cutin.finish();require(logic.snapshot()==snapshot,"all probes leave state unchanged")
    print("BATTLE_IDLE_CANDIDATE checks=",checks," failures=0");quit()
