extends "res://tests/support/test_case.gd"
var g
var app
func _initialize():call_deferred('run')
func setup(kind='default'):
    var data=Content.reference_content() if kind=='reference' else Content.default_content()
    if kind!='reference':
        for y in range(data.height):data.terrain[y]='G'.repeat(data.width)
    data.units[2].x=5;data.units[2].y=6
    data.units[3].x=5;data.units[3].y=5;data.units[3].hp=1
    data.units[4].x=4;data.units[4].y=5
    data.units[5].x=6;data.units[5].y=5
    if kind=='injured':
        data.units[3].x=3;data.units[3].y=5;data.units[3].hp=12;data.units[3].controller='player'
    app.new_game(data);change_scene_to_file('res://main.tscn');await process_frame;await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    g=current_scene;g.refresh()
    for node in [g,g.motion,g.cutin,g.heal_feedback,g.event_sequence,g.map_magic]:node.set_process(false)
func submit(command):
    check(app.session.submit(command),'Lua accepts '+str(command))
    g.battle=app.session.logic;g.refresh()
func tick(delta):
    g.map_magic._process(delta);g.motion.advance(delta);g.cutin._process(delta);g.heal_feedback._process(delta);g.event_sequence._process(delta)
func drain():
    var n=0
    while g.presentation_active() and n<300:tick(0.05);n+=1
    check(n<300,'bounded queue completion')
func dock_hp(expected,label):
    var unit=g.battle.units[g.selected]
    check(g.hud.dock.hp.value==expected and g.hud.dock.hp_value.text=="%d/%d"%[expected,unit.max_hp],label)
func run():
    app=root.get_node('App');app.sfx_enabled=false
    await setup()
    submit({'kind':'ability','ability':'ember','unit':2,'target':3})
    var truth=g.battle.snapshot();var hash=g.battle.state_hash();var emitted=g.battle.events.filter(func(e):return e.get('kind')=='attack')
    check(emitted.size()==3,'actual multi-target ember events')
    check(g.map_magic.active and not g.cutin.active,'magic routed to map')
    check(g.event_sequence.map_items.size()==3,'AoE shares one casting cue')
    check(g.figures[3].visible and g.badges[3].previous_hp==1,'killed actor retained before impact')
    check(g.targeting_locked(),'input blocked during magic')
    var touch=InputEventScreenTouch.new();touch.index=0;touch.pressed=true;touch.position=Vector2(400,300);g._unhandled_input(touch)
    check(g.map_touch==-1,'mobile touch cannot acquire gesture during magic')
    tick(0.61);check(g.figures[3].visible,'no early death')
    tick(0.02)
    check(not g.figures[3].visible and g.map_magic.labels.size()==3,'death and numbers at exact impact')
    for e in emitted:check(g.event_sequence.health[e.target]==e.hp,'event HP at impact '+e.target)
    var impacts=g.map_magic.impact_count
    g.refresh();check(g.map_magic.impact_count==impacts and g.map_magic.active,'same-step refresh preserves playback')
    drain();check(g.battle.snapshot()==truth and g.battle.state_hash()==hash,'presentation leaves deterministic state unchanged')
    check(g.map_magic.impact_count==3,'one impact per authoritative target')
    g.refresh();check(not g.presentation_active(),'same step not replayed')
    await setup()
    submit({'kind':'attack','unit':2,'target':3})
    check(g.cutin.active and not g.map_magic.active,'Neri physical basic attack retains audible visible cut-in')
    g.skip_presentation()
    await setup()
    submit({'kind':'ability','ability':'focus_bolt','unit':2,'target':3})
    truth=g.battle.snapshot();check(g.map_magic.active and g.battle.units[2].mp==4,'focus bolt map route with Lua MP cost')
    tick(0.3);g.skip_presentation();check(g.battle.snapshot()==truth and not g.presentation_active(),'skip before impact settles truth')
    check(g.map_magic.labels.is_empty() and not g.figures[3].visible,'skip removes transient effects and settles dead unit')
    await setup('injured')
    submit({'kind':'attack','unit':3,'target':0});g.skip_presentation()
    var wounded=g.battle.units[0].hp
    submit({'kind':'skill','unit':0,'target':0})
    truth=g.battle.snapshot();check(g.map_magic.active and g.badges[0].previous_hp==wounded,'rally HP delayed until impact')
    dock_hp(wounded,'visible dock before healing')
    tick(0.40);g.hud.dock.refresh_dock();dock_hp(wounded,'visible dock during travel and layout refresh')
    tick(0.23);dock_hp(wounded+3,'visible dock updates at healing impact')
    check(g.badges[0].previous_hp==wounded+3 and g.map_magic.labels[0].node.text=='+3','actual heal amount at impact')
    drain();check(g.battle.snapshot()==truth,'healing presentation never heals twice')
    await setup('injured')
    submit({'kind':'attack','unit':3,'target':0});g.skip_presentation()
    submit({'kind':'item','unit':0,'target':0,'consumable':'bandage'})
    check(g.map_magic.active,'existing healing item routes by heal event')
    g.skip_presentation()
    await setup()
    app.reduced_motion=true
    submit({'kind':'ability','ability':'focus_bolt','unit':2,'target':3})
    var camera_before=g.camera.transform
    tick(0.63);check(g.camera.transform==camera_before and g.map_magic.original_colors.get(3,Color.WHITE)==g.figures[3].modulate,'reduced motion has no shake or flash')
    check(g.map_magic.labels.size()==1,'reduced motion retains results')
    # New contiguous authoritative command queues behind in-flight spell.
    submit({'kind':'end_turn'})
    check(not g.event_sequence.batches.is_empty(),'enemy turn queues behind spell')
    truth=g.battle.snapshot();drain();check(g.battle.snapshot()==truth,'enemy queue preserves latest authoritative snapshot')
    app.reduced_motion=false
    await setup()
    submit({'kind':'ability','ability':'focus_bolt','unit':2,'target':3})
    var last=g.event_sequence.last_step
    g.event_sequence.consume(last+3,[])
    check(not g.map_magic.active and not g.presentation_active(),'reconnect gap cleans up stale magic')
    await setup('reference')
    app.mobile_presentation=true;g.scene_view.fit()
    var pan=g.scene_view.pan
    submit({'kind':'ability','ability':'ember','unit':2,'target':3})
    tick(0.4)
    check(g.scene_view.pan.abs().x<=g.scene_view.pan_limit.x and g.scene_view.pan.abs().y<=g.scene_view.pan_limit.y,'camera focus within authored map bounds')
    g.skip_presentation();check(g.scene_view.pan==pan,'skip restores camera pan')
    app.mobile_presentation=false
    await setup('injured')
    submit({'kind':'attack','unit':3,'target':0})
    var injury=g.battle.units[0].hp
    dock_hp(12,'queued damage holds visible HP before cut-in result')
    submit({'kind':'skill','unit':0,'target':0})
    truth=g.battle.snapshot();var healed=g.battle.units[0].hp
    dock_hp(12,'queued heal cannot leak final HP across earlier damage')
    check(not g.select_actor(1),'actor selection locked across damage/heal queue')
    g.cutin.finish();g.event_sequence._process(0)
    check(g.map_magic.active,'queued heal starts after actual damage presentation')
    dock_hp(injury,'visible dock uses injury HP at start of queued healing')
    tick(0.40)
    var replacement=Runtime.new(g.battle.content)
    check(replacement.restore(truth),'same-step reconnect snapshot')
    app.session.logic=replacement;g.battle=replacement;g.refresh()
    dock_hp(injury,'same-step replacement preserves in-flight dock HP')
    tick(0.23);dock_hp(healed,'queued heal impact updates visible dock')
    check(g.battle.snapshot()==truth,'dock and heal never mutate authoritative snapshot')
    drain();check(g.select_actor(1),'selection resumes after queued presentation')
    dock_hp(g.battle.units[1].hp,'visible dock follows newly selected actor')
    await setup('injured')
    submit({'kind':'attack','unit':3,'target':0});g.skip_presentation()
    submit({'kind':'skill','unit':0,'target':0});tick(0.4)
    g.event_sequence.consume(g.event_sequence.last_step+3,[])
    dock_hp(g.battle.units[0].hp,'reconnect gap settles visible dock to truth')
    print('MAP_MAGIC checks=',checks,' failures=',failures,' real_lua=true')
    quit(1 if failures else 0)
