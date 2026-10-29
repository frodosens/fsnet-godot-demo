extends 'res://tests/test_map_magic.gd'
func combined_setup(generic_target=false,generic_actor=false):
    var data=preload('res://logic/content.gd').default_content();data.story.events=[]
    for y in range(data.height):data.terrain[y]='G'.repeat(data.width)
    data.units[0].x=4;data.units[0].y=5
    data.units[2].x=5;data.units[2].y=6
    data.units[3].x=5;data.units[3].y=5
    data.units[4].x=6;data.units[4].y=5
    data.units[5].x=5;data.units[5].y=4
    if generic_target:data.units[3].id='generic_bandit_01'
    if generic_actor:data.units[0].id='generic_soldier_01'
    app.new_game(data);change_scene_to_file('res://main.tscn');await process_frame;await process_frame
    g=current_scene;g.refresh()
    for node in [g,g.motion,g.cutin,g.heal_feedback,g.event_sequence,g.map_magic,g.generic_attack_feedback]:node.set_process(false)
func tick_all(delta):
    g.generic_attack_feedback._process(delta);tick(delta)
func drain_all():
    var n=0
    while g.presentation_active() and n<300:tick_all(.05);n+=1
    check(n<300,'combined queue drains')
func run():
    app=root.get_node('App');app.sfx_enabled=false
    await combined_setup(true)
    submit({'kind':'ability','ability':'ember','unit':2,'target':3})
    var truth=g.battle.snapshot();var emitted=g.battle.events.filter(func(e):return e.get('kind')=='attack')
    check(g.map_magic.active and not g.cutin.active and not g.generic_attack_feedback.active(),'magic to generic recipient takes only magic route')
    check(g.map_magic.core.authored.values().all(func(v):return v),'all three admitted authored atlases active')
    tick_all(.63)
    check(g.map_magic.impact_count==emitted.size() and g.map_magic.labels.size()==emitted.size(),'one magic result per actual recipient')
    check(g.heal_feedback.numbers.is_empty() and not g.generic_attack_feedback.label.visible,'no duplicate legacy or generic numbers')
    drain_all();check(g.battle.snapshot()==truth,'generic-target magic preserves authoritative state')
    await combined_setup()
    submit({'kind':'attack','unit':2,'target':3})
    check(g.cutin.active and not g.map_magic.active and not g.generic_attack_feedback.active(),'Neri physical basic attack takes only supported cut-in')
    g.skip_presentation()
    for attacker in [false,true]:
        await combined_setup(not attacker,attacker)
        submit({'kind':'attack','unit':0,'target':3})
        truth=g.battle.snapshot()
        check(g.generic_attack_feedback.active() and not g.cutin.active and not g.map_magic.active,'unsupported physical attack takes only generic feedback')
        check(not g.select_actor(1),'generic route retains input lock')
        drain_all();check(g.battle.snapshot()==truth,'generic feedback never applies duplicate damage')
        check(not g.generic_attack_feedback.active() and not g.map_magic.active,'generic route cleanup')
    await combined_setup(true)
    submit({'kind':'ability','ability':'focus_bolt','unit':2,'target':3})
    submit({'kind':'end_turn'})
    truth=g.battle.snapshot();drain_all()
    check(g.battle.snapshot()==truth and g.map_magic.impact_count==1,'queued enemy actions preserve one spell impact')
    check(not g.map_magic.particles.running and not g.generic_attack_feedback.active(),'all combined effects settled')
    check(g.hud.root.has_node('HomewardBubbles'),'verified main story bubble presentation retained')
    print('MAP_MAGIC_COMBINED checks=',checks,' failures=',failures,' exclusive_routes=true authored_core=true')
    quit(1 if failures else 0)
