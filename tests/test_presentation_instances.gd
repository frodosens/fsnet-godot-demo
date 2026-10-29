extends "res://tests/support/test_case.gd"
const P=preload("res://logic/presentation_profiles.gd")
const C=preload("res://logic/content.gd")
const F=preload("res://tests/unit_definition_fixture.gd")
func _initialize():call_deferred("run")
func frames():
    for i in 4:await process_frame
func run():
    var app=root.get_node("App");app.sfx_enabled=false
    if OS.get_environment("UNIT_SMALL")=="1":root.size=Vector2i(960,600)
    var step=1
    var cutin=load("res://ui/battle_cutin.gd").new();root.add_child(cutin)
    for actor in P.HEROES:
        for target in P.HEROES:
            var e={"kind":"attack","actor":actor,"target":target,"ability":"attack","damage":2,"hp":6}
            var units=[{"id":actor,"name":"A","ally":true,"hp":8,"max_hp":8},{"id":target,"name":"B","ally":false,"hp":6,"max_hp":8}]
            if actor==target:continue
            cutin.consume(step,[e],units);step+=1;require(cutin.active,"canonical cutin")
            var originals=[]
            for tick in [0,8,10,16,23]:
                cutin.draw_tick(tick);originals.append([cutin.attacker.texture,cutin.defender.texture,cutin.attacker.position,cutin.defender.position,cutin.contact_target,cutin.tick_seconds,cutin.hit_tick()])
            cutin.finish()
            e.actor="independent_a";e.target="independent_b"
            units[0].id=e.actor;units[0].presentation_ref=actor;units[1].id=e.target;units[1].presentation_ref=target
            cutin.consume(step,[e],units);step+=1
            require(cutin.active and cutin.event.actor=="independent_a","instance identity retained")
            var n=0
            for tick in [0,8,10,16,23]:
                cutin.draw_tick(tick)
                require(originals[n]==[cutin.attacker.texture,cutin.defender.texture,cutin.attacker.position,cutin.defender.position,cutin.contact_target,cutin.tick_seconds,cutin.hit_tick()],"profile identical authored poses/timing "+actor+"/"+target);n+=1
            cutin.finish()
    cutin.queue_free();await frames()
    for profile in P.HEROES+P.GENERICS:
        var d=F.twins(profile);require(app.new_game(d),"admit duplicate profile "+profile)
        change_scene_to_file("res://main.tscn");await frames();var g=current_scene;g.refresh();g.scene_view.set_fixed(OS.get_environment("UNIT_3D")!="1");g.motion.set_process(false)
        for direction in ["front_left","front_right","back_left","back_right"]:
            for i in 2:g.apply_map_idle_texture(i,direction)
            var guard=g.base_directional_idle_texture(0,direction)
            if profile in ["mara","finn","neri","rodd"]+P.GENERICS:require(not g.hero_refresh_entry(0,direction).is_empty(),"latest profile admitted "+profile)
            elif profile in ["oren","tessa","bram"]:require(not preload("res://view/map_sequence.gd").shared().matching(profile,direction,guard).is_empty(),"canonical body guard "+profile)
            require(g.figures[0].texture==g.figures[1].texture and g.figures[0].flip_h==g.figures[1].flip_h,"same immutable idle art")
            for phase in [0.0,0.3,0.7]:
                g.apply_map_motion_texture(0,direction,phase);g.apply_map_motion_texture(1,direction,phase)
                require(g.figures[0].texture==g.figures[1].texture and g.figures[0].offset==g.figures[1].offset,"same profile phase independent instances")
        var before=g.battle.snapshot()
        g.select_actor(0)
        require(app.session.submit({"kind":"move","actor_id":"custom_guard_0","x":2,"y":6}),"legal instance move")
        g.battle=app.session.logic;g.refresh();g.motion.advance(.1)
        require(g.motion.motions.has("custom_guard_0") and not g.motion.motions.has("custom_guard_1"),"independent motion state")
        var travelled=g.motion.motions.custom_guard_0.travelled
        var r=preload("res://logic/runtime.gd").new(g.battle.content);require(r.restore(g.battle.snapshot()),"replacement restore")
        g.battle=r;g.refresh()
        require(g.motion.motions.custom_guard_0.travelled==travelled,"same-state replacement never restarts")
        g.skip_presentation();require(g.battle.units[1].pos==Vector2i(4,6),"other instance unmoved")
        require(g.battle.snapshot()!=before,"actual legal command changed state")
        var output=OS.get_environment("UNIT_CAPTURE")
        if not output.is_empty() and profile=="generic_bandit_01":
            await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output)
    print("PRESENTATION_INSTANCES checks=",checks," failures=",failures);quit(1 if failures else 0)
