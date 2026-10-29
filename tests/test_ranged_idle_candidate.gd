extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.reduced_motion=false;app.sfx_enabled=false
    var c=load("res://ui/battle_cutin.gd").new();root.add_child(c);c.set_process(false)
    for id in ["finn","neri"]:
        var data=Content.reference_content();var i=1 if id=="finn" else 2
        data.units[3].x=data.units[i].x+1;data.units[3].y=data.units[i].y
        var logic=Runtime.new(data)
        require(logic.apply_command({"kind":"end_turn","step":1}),"real AI turn "+id)
        c.last_seen_step=-1;c.consume(1,logic.events,logic.units,data)
        require(c.event.actor=="oren" and c.event.target==id,"actual target "+id)
        var truth=logic.snapshot();var clip=c.idle_library.clips.battle[id+":right"]
        require(clip.unit_ids==[id],"unit scoped")
        c.draw_tick(6);require(c.defender.texture==clip.textures[1] and not c.defender.flip_h and not c.actor_left,"own-side inhale faces enemy on right")
        c.draw_tick(7);require(c.defender.texture==c.defender_sets[id].idle,"brace remains original")
        c.draw_tick(9);require(c.defender.texture==c.defender_sets[id].hit,"hit remains original")
        c.draw_tick(13);require(c.defender.texture==c.defender_sets[id].recover,"recover remains original")
        c.draw_tick(23);require(c.defender.texture==c.defender_sets[id].recover,"end recovery not overwritten")
        app.reduced_motion=true;c.draw_tick(6);require(c.defender.texture==clip.textures[0],"reduced motion");app.reduced_motion=false
        for rate in [1.0,2.0,4.0]:
            c.last_seen_step=-1;c.speed=rate;c.consume(1,logic.events,logic.units,data)
            var shown=false;var n=0;var hits=c.impact_play_count
            while c.active and n<400:
                c._process(1.0/120.0);n+=1;shown=shown or c.defender.texture==clip.textures[1]
            require(shown and not c.active,"actual process observes inhale at "+str(rate))
            require(c.impact_play_count==hits+1,"one hit")
        c.finish();require(logic.snapshot()==truth,"presentation never changes Lua")
        # Own attack source remains authored; no new clip overwrites draw/cast.
        c.event={"actor":id,"target":"oren","damage":1,"hp":5,"ability":"attack" if id=="finn" else "ember"}
        c.tick_seconds=c.actor_sets[id].tick_seconds;c.release_tick=c.actor_sets[id].release
        for frame in range(24):
            c.draw_tick(frame)
            require(c.attacker.texture==c.actor_sets[id].textures[int(c.actor_sets[id].timeline[frame])],"own action unchanged")
    c.finish();print("RANGED_IDLE_CANDIDATE checks=",checks," failures=0");quit()
