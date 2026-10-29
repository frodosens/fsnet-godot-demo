extends SceneTree
func _initialize():
    var data=Content.default_content();data.width=16;data.height=16;data.terrain=[]
    for y in range(16):data.terrain.append("GGGGGGGGGGGGGGGG")
    var prototype=data.units[0].duplicate(true);data.units=[]
    for i in range(16):
        var u=prototype.duplicate(true);u.id="unit_"+str(i);u.ally=i<8;u.controller="ai";u.x=i%8*2;u.y=0 if i<8 else 15;u.movement=8
        data.units.append(u)
    assert(Content.validate(data).is_empty())
    var timings=[];var accepted=true;var bytes=0
    for repeat in range(20):
        var logic=Runtime.new(data);var before=logic.snapshot();var start=Time.get_ticks_usec()
        var ok=logic.apply_command({"kind":"end_turn","step":1})
        timings.append(Time.get_ticks_usec()-start);accepted=accepted and ok;bytes=logic.snapshot().length()
        assert(ok or logic.snapshot()==before)
    timings.sort()
    print("CONTENT_BUDGET accepted=",accepted," repetitions=20 p50_us=",timings[10]," p95_us=",timings[18]," max_us=",timings[19]," snapshot_bytes=",bytes," workload=16_AI_16x16_move8")
    quit(0 if accepted else 1)
