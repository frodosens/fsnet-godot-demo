extends 'res://tests/test_map_magic.gd'
func clean_pool(label):
    var pool=g.map_magic.particles
    check(not pool.running and pool.all_emitters.all(func(p):return not p.visible and not p.emitting and not p.is_processing_internal()),label)
func run():
    app=root.get_node('App');app.sfx_enabled=false;app.reduced_motion=false
    await setup()
    var pool=g.map_magic.particles
    check(pool.all_emitters.size()==17 and pool.all_emitters.all(func(p):return p is CPUParticles2D),'17 real CPUParticles2D engine nodes')
    check(pool.MAX_PARTICLES==336 and pool.all_emitters.reduce(func(n,p):return n+p.amount,0)==336,'hard particle capacity 336')
    check(pool.all_emitters.all(func(p):return p.use_fixed_seed and p.local_coords and p.fixed_fps==30),'visual seed and fixed-step particle simulation independent of Lua')
    var identities=pool.all_emitters.map(func(p):return p.get_instance_id())
    submit({'kind':'ability','ability':'ember','unit':2,'target':3})
    var truth=g.battle.snapshot()
    check(pool.style=='ember' and pool.cast.emitting and pool.cast.is_processing_internal(),'engine cast emitter actually running')
    tick(.40)
    check(pool.slots.slice(0,3).all(func(s):return s.trail.emitting and s.trail.is_processing_internal()),'three real engine trails emitting')
    check(pool.slots[0].trail.gravity.y<0 and pool.slots[0].burst.gravity.y>0,'fire has rising sparks and falling burst arcs')
    tick(.23)
    check(pool.burst_started and pool.slots.slice(0,3).all(func(s):return s.burst.emitting and s.burst.one_shot),'engine impact bursts launched at impact')
    check(pool.all_emitters.all(func(p):return p.lifetime<=.55),'particle lifetime bounded')
    check(g.battle.snapshot()==truth,'particle simulation never changes authority')
    g.skip_presentation();clean_pool('skip hides clears and stops every emitter immediately')
    check(pool.all_emitters.map(func(p):return p.get_instance_id())==identities,'pool reused without reallocating nodes')
    # Drive emitter-only pool stress with actual event shape; no fake reducer result.
    var e={'kind':'attack','actor':'neri','target':'oren','ability':'ember'}
    g.map_magic.points={'neri':Vector3(5,0,6),'oren':Vector3(5,0,5)};g.map_magic.items=[e]
    var many=[]
    for i in range(64):many.append(e)
    for i in range(5):pool.start(many);pool.advance(.4);pool.stop()
    check(pool.all_emitters.map(func(p):return p.get_instance_id())==identities,'64-target decorative overload does not expand pool')
    pool.start(many);check(pool.entries.size()==8,'decoration limited to first eight recipients; owner retains all results');pool.stop()
    g.map_magic.points={'neri':Vector3(1000,0,1000),'oren':Vector3(1001,0,1000)}
    pool.start([e]);pool.advance(.4);pool.advance(.63)
    check(pool.all_emitters.all(func(p):return not p.visible and not p.emitting),'offscreen emissions culled')
    pool.stop();g.map_magic.finish()
    await setup()
    submit({'kind':'ability','ability':'focus_bolt','unit':2,'target':3})
    pool=g.map_magic.particles;truth=g.battle.snapshot();tick(.4)
    check(pool.style=='bolt' and pool.slots[0].trail.gravity==Vector2.ZERO and pool.slots[0].trail.spread==12,'focus bolt has narrow energy trail')
    var point=pool.to_global(pool.slots[0].trail.emission_points[1])
    var source=g.map_magic.screen('neri',.55);var target=g.map_magic.screen('oren',.5)
    check(point.distance_to(source.lerp(target,(.4-.30)/(.62-.30)))<.01,'particle emitter anchored to actual projected path')
    app.reduced_motion=true;tick(.01);clean_pool('reduced motion toggled during cast stops all particles')
    tick(.23);check(g.map_magic.labels.size()==1 and g.battle.snapshot()==truth,'reduced motion retains actual impact result')
    g.skip_presentation()
    await setup();submit({'kind':'ability','ability':'ember','unit':2,'target':3});clean_pool('reduced motion starts without particles');g.skip_presentation();app.reduced_motion=false
    await setup('injured')
    submit({'kind':'attack','unit':3,'target':0});g.skip_presentation()
    submit({'kind':'skill','unit':0,'target':0});pool=g.map_magic.particles;truth=g.battle.snapshot();tick(.4)
    check(pool.style=='heal' and pool.slots[0].trail.direction==Vector2.UP and pool.slots[0].trail.gravity.y<0,'healing uses ascending engine light motes')
    check(pool.slots[0].trail.emitting,'healing particles actually emit')
    var original=g.map_magic.elapsed
    var replacement=preload('res://logic/runtime.gd').new(g.battle.content);check(replacement.restore(truth),'particle replay fixture')
    app.session.logic=replacement;g.battle=replacement;g.refresh()
    check(g.map_magic.elapsed==original and pool.running,'same-step VM replacement preserves particle lifecycle')
    g.event_sequence.consume(g.event_sequence.last_step+3,[]);clean_pool('reconnect gap clears all particles')
    await setup();submit({'kind':'ability','ability':'focus_bolt','unit':2,'target':3});tick(.4)
    var old=g.map_magic.particles.all_emitters.duplicate()
    change_scene_to_file('res://ui/menu.tscn');await process_frame;await process_frame
    check(old.all(func(p):return not is_instance_valid(p)),'scene exit destroys entire pool')
    print('MAP_PARTICLES checks=',checks,' failures=',failures,' actual_nodes=17 capacity=336 max_lifetime=.55 independent_visual_seed=true')
    quit(1 if failures else 0)
