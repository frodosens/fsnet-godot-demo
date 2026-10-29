extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.sfx_enabled=false;app.reduced_motion=false
    var c=load("res://ui/battle_cutin.gd").new();root.add_child(c);c.set_process(false)
    require(c.idle_library.errors.is_empty() and c.idle_library.clips.battle.size()==7,"seven source-state clips")
    for key in c.idle_library.clips.battle:
        var clip=c.idle_library.clips.battle[key];var id=key.split(":")[0];var fallback=c.actor_sets.oren.textures[0]
        require(clip.unit_ids==[id],"unit-scope "+key)
        for entry in [[0,0],[.319,0],[.32,1],[.639,1],[.64,2],[.959,2],[.96,0]]:
            require(c.idle_library.sample("battle",key,entry[0],fallback,false,id)==clip.textures[entry[1]],"clip clock "+key)
        require(c.idle_library.sample("battle",key,.4,fallback,true,id)==clip.textures[0],"reduced motion")
        require(c.idle_library.sample("battle",key,.4,fallback,false,"mod-other")==fallback,"other identity fallback")
    var events=[];var units=[];var content={}
    for id in ["tessa","bram"]:
        var data=Content.reference_content();var i=4 if id=="tessa" else 5
        data.units[i].x=data.units[0].x+1;data.units[i].y=data.units[0].y
        var logic=Runtime.new(data)
        require(logic.apply_command({"kind":"attack","actor_id":"mara","target_id":id,"step":1}),"real player attack "+id)
        var truth=logic.snapshot();c.last_seen_step=-1;c.consume(1,logic.events,logic.units,data)
        var clip=c.idle_library.clips.battle[id+":right"]
        c.draw_tick(5);require(c.defender.texture==clip.textures[1] and c.defender.flip_h,"visible mirrored inhale")
        c.draw_tick(8);require(c.defender.texture==c.defender_sets[id].idle,"brace excludes new idle")
        c.draw_tick(10);require(c.defender.texture==c.defender_sets[id].hit,"hit precedence")
        c.draw_tick(14);require(c.defender.texture==c.defender_sets[id].recover,"recovery precedence")
        c.draw_tick(23);require(c.defender.texture==c.defender_sets[id].recover,"final recovery precedence")
        for rate in [1.0,2.0,4.0]:
            c.speed=rate;c.last_seen_step=-1;c.consume(1,logic.events,logic.units,data)
            var shown=false;var n=0;var hits=c.impact_play_count
            while c.active and n<600:
                c._process(1.0/120.0);n+=1;shown=shown or c.defender.texture==clip.textures[1]
            require(shown and not c.active and c.impact_play_count==hits+1,"speed with one impact")
        c.last_seen_step=-1;c.consume(1,logic.events,logic.units,data);c.elapsed=5*c.tick_seconds;c.draw_tick(5)
        c.set_process(true);paused=true;await create_timer(.03,true).timeout
        require(c.elapsed==5*c.tick_seconds and c.defender.texture==clip.textures[1],"pause actual tree")
        paused=false;c.set_process(false);c.finish();require(not c.active,"skip")
        c.consume(1,logic.events,logic.units,data);require(not c.active,"same step deduplicated")
        require(logic.snapshot()==truth,"unchanged Lua state")
        events+=logic.events;units=logic.units;content=data
    c.last_seen_step=-1;c.consume(55,events,units,content);require(c.event.target=="tessa","first queued target")
    c.draw_tick(5);c.play_next();require(c.event.target=="bram" and c.elapsed==0 and c.defender.texture==c.defender_sets.bram.idle,"queue resets identity and clock")
    c.event.hp=0;c.draw_tick(23);require(c.defender.texture==c.defender_sets.bram.hit,"death never idle")
    # Oren-right exists, but the 120ms active neutral window cannot reach inhale320ms.
    # Explicitly test this limitation instead of manufacturing a visible full cycle.
    c.event={"actor":"oren","target":"mara","damage":1,"hp":11,"ability":"attack"};c.tick_seconds=.06;c.release_tick=9
    for frame in range(24):
        c.draw_tick(frame)
        require(c.attacker.texture==c.actor_sets.oren.textures[int(c.actor_sets.oren.timeline[frame])],"Oren right authored timeline unchanged")
    require(c.idle_library.clips.battle["oren:right"].textures[0]!=c.idle_library.clips.battle["oren:left"].textures[0],"left and right separate originals")
    c.finish();print("ALL_BATTLE_IDLES checks=",checks," failures=0");quit()
