extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.sfx_enabled=false;var data=Content.default_content()
    for y in range(data.height):data.terrain[y]="G".repeat(data.width)
    data.units[3].x=3;data.units[3].y=3;data.units[4].x=5;data.units[4].y=3;data.units[5].x=6;data.units[5].y=4
    app.new_game(data);change_scene_to_file("res://main.tscn");await process_frame;await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    var g=current_scene;g.refresh()
    for node in [g,g.motion,g.cutin,g.heal_feedback,g.event_sequence,g.active_actor_marker]:node.set_process(false)
    var marker=g.active_actor_marker;marker._process(0)
    require(marker.actor_index==g.selected,"idle selection marker")
    require(app.session.submit({"kind":"end_turn"}),"actual AI turn")
    g.battle=app.session.logic;g.refresh();var truth=g.battle.snapshot()
    var seen={};var ticks=0
    while g.presentation_active() and ticks<4000:
        marker._process(1.0/60)
        var event=g.event_sequence.current
        if not event.is_empty() and event.has("actor"):
            require(g.battle.units[marker.actor_index].id==event.actor,"marker follows executing actor instead of selected ally")
            if not g.battle.units[marker.actor_index].ally:
                seen[event.actor]=true
                require(marker.arrow.texture==marker.enemy_arrow,"enemy execution uses enemy color")
            require(marker.foot.position.distance_to(Vector3(g.figures[marker.actor_index].position.x,.045,g.figures[marker.actor_index].position.z))<.001,"foot marker tracks actual presentation position")
        g.motion.advance(.1);g.cutin._process(.1);g.heal_feedback._process(.1);g.event_sequence._process(.1);ticks+=1
    require(ticks<4000 and seen.size()>=2,"multiple real enemies complete")
    marker._process(0);require(marker.actor_index==g.selected,"settled marker returns to selection")
    require(g.battle.snapshot()==truth,"markers never modify authoritative snapshot")
    g.hud.show_feedback_settings();marker._process(0);require(not marker.arrow.visible and not marker.foot.visible,"modal hides decorative markers")
    g.hud.clear_modal();marker._process(0)
    app.reduced_motion=true;var old=marker.clock;marker._process(5);require(marker.clock==old and marker.foot.scale==Vector3.ONE,"reduced motion static diamond")
    print("ACTIVE_ACTOR_MARKER checks=",checks," failures=0");quit()
