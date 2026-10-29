extends 'res://tests/test_map_magic.gd'
func run():
    app=root.get_node('App');app.sfx_enabled=false;app.reduced_motion=false
    await setup()
    var fx=g.map_magic;var core=fx.core
    check(fx.timeline is AnimationPlayer,'real AnimationPlayer owns presentation clock')
    check(core.caster is AnimatedSprite2D and core.targets.size()==8 and core.targets.all(func(s):return s is AnimatedSprite2D),'nine bounded real AnimatedSprite2D nodes')
    for id in core.frame_sets:
        var frames=core.frame_sets[id]
        check(frames is SpriteFrames,'real SpriteFrames '+id)
        var expected=[4,4,8] if core.authored[id] else [2,1,2]
        check([frames.get_frame_count('cast'),frames.get_frame_count('travel'),frames.get_frame_count('impact')]==expected,'honest authored/fallback stage counts '+id)
    var animation=fx.timeline.get_animation('spell')
    check(animation.get_track_count()==4,'bounded phase frame clock and path tracks')
    for i in range(animation.get_track_count()):check(animation.track_get_type(i)==Animation.TYPE_VALUE,'no gameplay method tracks')
    submit({'kind':'ability','ability':'focus_bolt','unit':2,'target':3})
    var truth=g.battle.snapshot()
    var first_frame=core.caster.frame
    await process_frame;await process_frame
    check(core.caster.frame==first_frame and not core.caster.is_playing() and core.targets.all(func(s):return not s.is_playing()),'no SpriteFrames autoplay or second phase clock')
    tick(.16)
    check(core.phase==0 and core.caster.animation=='cast' and core.caster.frame>0,'AnimationPlayer advances real cast frames')
    tick(.24)
    check(core.phase==1 and core.targets[0].animation=='travel' and core.targets[0].visible,'AnimationPlayer changes travel phase')
    check(is_equal_approx(core.travel_progress,.3125),'AnimationPlayer drives projectile progress')
    var source=fx.screen('neri',.55);var target=fx.screen('oren',.5)
    check(core.targets[0].position.distance_to(source.lerp(target,core.travel_progress))<.01,'core anchored to exact projected path')
    fx.set_process(true);g.event_sequence.set_process(true)
    var age=fx.elapsed;var frame=core.targets[0].frame
    paused=true;await process_frame;await process_frame
    check(fx.elapsed==age and core.targets[0].frame==frame,'pause freezes timeline/core frames')
    check(fx.particles.all_emitters.all(func(p):return not p.can_process()),'pause freezes engine particle processing')
    paused=false;fx.set_process(false);g.event_sequence.set_process(false)
    tick(.23)
    check(core.phase==2 and core.targets[0].animation=='impact' and not g.figures[3].visible,'impact phase and authoritative projected death coincide')
    check(g.battle.snapshot()==truth,'timeline has no gameplay side effects')
    g.skip_presentation()
    check(not fx.timeline.is_playing() and not core.running and not core.caster.visible and core.targets.all(func(s):return not s.visible),'skip clears timeline and all core nodes')
    check(not fx.particles.running,'skip clears particle layer too')
    check(core.targets.all(func(s):return s.rotation==0 and s.scale==Vector2.ONE and s.position==Vector2.ZERO and s.frame==0),'pooled core transforms and frame reset')
    await setup()
    submit({'kind':'ability','ability':'focus_bolt','unit':2,'target':3})
    fx=g.map_magic;truth=g.battle.snapshot()
    var count=fx.impact_count
    fx.timeline.seek(.9,true)
    check(fx.impact_count==count and g.battle.snapshot()==truth,'AnimationPlayer seek itself never applies a result')
    fx._process(0)
    check(fx.impact_count==count+1,'owner observes a crossed impact once after forward seek')
    fx.timeline.seek(1.2,true);fx._process(0)
    check(fx.impact_count==count+1 and g.battle.snapshot()==truth,'later seek cannot double apply impact')
    g.skip_presentation();g.refresh()
    check(not fx.active and not fx.timeline.is_playing() and fx.core.targets.all(func(s):return not s.visible),'skip after seek leaves no auto-replay')
    await setup('injured');submit({'kind':'attack','unit':3,'target':0});g.skip_presentation()
    submit({'kind':'skill','unit':0,'target':0});tick(.4)
    check(g.map_magic.core.style=='heal' and g.map_magic.core.targets[0].rotation==0,'healing core ascends without projectile rotation')
    print('MAP_SPELL_CORE checks=',checks,' failures=',failures,' diagnostics=',JSON.stringify(g.map_magic.core.diagnostics()))
    quit(1 if failures else 0)
