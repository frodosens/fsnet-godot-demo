extends SceneTree
var checks=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");var d=preload("res://logic/content.gd").default_content();d.story.events=[]
    for y in range(d.height):d.terrain[y]="G".repeat(d.width)
    var ids=["ch01_bandit_a","ch01_bandit_b","ch01_bandit_c"]
    for i in 3:
        d.units[i+3].id=ids[i];d.units[i+3].name=["山贼甲","山贼乙","山贼丙"][i];d.units[i+3].x=[3,5,6][i];d.units[i+3].y=[3,3,4][i]
    check(preload("res://logic/content.gd").validate(d).is_empty(),"three enemy aliases validate without changing stats")
    app.new_game(d);change_scene_to_file("res://main.tscn");await process_frame;await process_frame
    var g=current_scene;g.refresh()
    for n in [g,g.motion,g.cutin,g.heal_feedback,g.generic_attack_feedback,g.event_sequence]:n.set_process(false)
    check(app.session.submit({"kind":"end_turn"}),"actual AI turn")
    g.battle=app.session.logic;var truth=g.battle.snapshot();var emitted=g.battle.events.duplicate(true);g.refresh()
    var expected=[];var attack_seen={};var frames=0
    for e in emitted:
        if e.kind in ["move","attack","heal"]:expected.append({"kind":e.kind,"actor":e.get("actor",""),"step":g.battle.step})
    check(expected.any(func(e):return e.kind=="attack"),"actual AI attacks")
    while g.presentation_active() and frames<4000:
        check(g.motion.motions.size()<=1,"independent instances queued, not simultaneous teleport")
        if g.generic_attack_feedback.active():
            var e=g.generic_attack_feedback.event;attack_seen[e.actor]=true
            check(e.actor in ids and g.generic_attack_feedback.label.visible,"own AI attacker named in visible feedback")
            check(not g.cutin.active,"no substituted hero cutin")
        g.motion.advance(1.0/60);g.cutin._process(1.0/60);g.heal_feedback._process(1.0/60);g.generic_attack_feedback._process(1.0/60);g.event_sequence._process(1.0/60);frames+=1
    check(frames<4000 and not attack_seen.is_empty(),"AI feedback finishes bounded")
    check(g.event_sequence.trace.filter(func(e):return e.kind in ["move","attack","heal"])==expected,"same authoritative order")
    check(g.battle.snapshot()==truth,"rendering leaves all three authoritative states unchanged")
    for i in range(g.battle.units.size()):check(g.figures[i].position==Vector3(g.battle.units[i].x,g.figure_height(i),g.battle.units[i].y),"own settled position")
    print("GENERIC_AI checks=",checks," failures=0 actors_with_feedback=",attack_seen.keys());quit()
