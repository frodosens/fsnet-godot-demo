extends SceneTree
var failures=0
func check(ok,label):
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App")
    var hero_refresh=OS.get_environment("AMBER_HERO_REFRESH")=="1"
    for id in app.hero_map_refresh_previews:app.hero_map_refresh_previews[id]=hero_refresh and OS.get_environment("AMBER_WALK_ACTOR")==id
    app.rodd_motion_preview=hero_refresh and OS.get_environment("AMBER_WALK_ACTOR")=="rodd"
    var elsbet_mirror=OS.get_environment("AMBER_ELSBET_MOTION")=="1"
    app.elsbet_motion_preview=elsbet_mirror
    var compact=OS.get_environment("AMBER_COMPACT_SEQUENCE")=="1"
    var adela_mirror=OS.get_environment("AMBER_ADELA_MOTION")=="1"
    app.adela_motion_preview=adela_mirror
    var neri_mirror=OS.get_environment("AMBER_NERI_MIRROR")=="1"
    app.neri_motion_preview=neri_mirror
    app.mara_sequence_preview=compact and OS.get_environment("AMBER_WALK_ACTOR")=="mara"
    app.tessa_motion_preview=compact and OS.get_environment("AMBER_WALK_ACTOR")=="tessa"
    app.finn_motion_preview=compact and OS.get_environment("AMBER_WALK_ACTOR")=="finn"
    app.oren_sequence_preview=compact and OS.get_environment("AMBER_WALK_ACTOR")=="oren"
    app.bram_sequence_preview=compact and OS.get_environment("AMBER_WALK_ACTOR")=="bram"
    for id in app.idle_sequence_previews:app.idle_sequence_previews[id]=compact and OS.get_environment("AMBER_WALK_ACTOR")==id
    if elsbet_mirror:app.idle_sequence_previews.elsbet=OS.get_environment("AMBER_ELSBET_IDLE")=="1"
    var data=preload("res://logic/content.gd").reference_content();data.units[1].x=1;data.units[1].y=8
    var actor=OS.get_environment("AMBER_WALK_ACTOR");if actor.is_empty():actor="finn"
    var direction=OS.get_environment("AMBER_WALK_DIRECTION");if direction.is_empty():direction="front_right"
    if OS.get_environment("AMBER_LATEST_MAP")=="1":
        app.load_presentation_preferences()
        hero_refresh=actor in ["mara","finn","neri","rodd"] or preload("res://view/generic_map_art.gd").declared(actor)
        elsbet_mirror=actor=="elsbet";adela_mirror=actor=="adela";neri_mirror=false
        compact=actor in ["oren","bram","tessa"]

    var target=Vector2i(4,8)
    if direction!="front_right" or actor!="finn":
        data=preload("res://tests/walk_rear_fixture.gd").content(actor,direction)
        target=preload("res://tests/walk_rear_fixture.gd").target(direction)
    var index=0
    for j in range(data.units.size()):
        if data.units[j].id==actor:index=j
    check(app.start_room(false,int(OS.get_environment("AMBER_TEST_PORT")),OS.get_environment("AMBER_TOKEN"),data),"connect real authority")
    var deadline=Time.get_ticks_msec()+15000
    while not app.session.ready or app.session.pending:
        await process_frame
        if Time.get_ticks_msec()>deadline:check(false,"connect timeout");quit(1);return
    change_scene_to_file("res://main.tscn");await process_frame;await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.motion.speed=.5
    while app.session.pending:await process_frame
    check(app.session.submit({"kind":"move","unit":index,"x":target.x,"y":target.y}),"network legal actor move")
    while game.battle.step<1:
        await process_frame
        if Time.get_ticks_msec()>deadline:check(false,"command timeout");quit(1);return
    var truth=game.battle.snapshot();var previous=0.0;var replacements=0;var runtime_id=game.battle.get_instance_id();var poses={};var samples=0
    while game.motion.active():
        var distance=game.motion.motions[actor].travelled
        check(distance+.00001>=previous,"ordinary sync never restarts travel")
        previous=distance;samples+=1
        if runtime_id!=game.battle.get_instance_id():replacements+=1;runtime_id=game.battle.get_instance_id()
        var clip=game.motion.walk_library.clips.get(actor+":"+direction,{})
        if compact and not app.idle_sequence_previews.has(actor):clip=preload("res://view/map_sequence.gd").shared().matching(actor,direction,game.base_directional_idle_texture(index,direction)).motion
        if neri_mirror:
            clip=game.neri_motion_entry(index,direction).motion
            check(game.figures[index].flip_h==(direction=="front_right"),"mirror survives Runtime replacement")
        if adela_mirror:
            clip=game.adela_motion_entry(index,direction).motion
            check(game.figures[index].flip_h==direction.ends_with("right"),"Adela mirror survives Runtime replacement")
        if actor=="vera":
            clip=game.vera_motion_entry(index,direction).motion
            check(game.figures[index].flip_h==direction.ends_with("right"),"Vera mirror survives Runtime replacement")
        if elsbet_mirror:
            clip=game.elsbet_motion_entry(index,direction).motion
            check(game.figures[index].flip_h==direction.ends_with("right") and game.figures[index].offset==Vector2(0,64),"Elsbet motion root/mirror persists")
        if hero_refresh:
            clip=game.hero_refresh_entry(index,direction).motion
            check(game.figures[index].flip_h==direction.ends_with("right") and game.figures[index].offset==Vector2(0,64),"hero root/mirror survives Runtime replacement")
        poses[clip.textures.find(game.figures[index].texture)]=true
        check(game.battle.snapshot()==truth,"poll keeps authoritative state")
        await process_frame
        if Time.get_ticks_msec()>deadline:check(false,"motion timeout");break
    check(replacements>=2 and samples>20,"real runtime replacements observed during walk")
    check(poses.size()==8 if elsbet_mirror or hero_refresh or actor=="vera" or neri_mirror or adela_mirror or (compact and not app.idle_sequence_previews.has(actor)) else (poses.has(1) and poses.has(3)),"real sync allows complete pose set")
    check(game.figures[index].position==Vector3(target.x,0,target.y),"network authoritative endpoint")
    var final_texture=game.directional_idle_texture(index,direction)
    game.get_node("MapIdle").set_process(false);game.figures[index].texture=final_texture
    var until=Time.get_ticks_msec()+500
    while Time.get_ticks_msec()<until:await process_frame
    check(not game.motion.active(),"post-completion polls don't replay")
    if elsbet_mirror:check(not game.figures[index].flip_h and game.figures[index].offset==Vector2(0,56),"Elsbet restores original stopped idle root/mirror")
    if hero_refresh:check(game.figures[index].flip_h==direction.ends_with("right") and game.figures[index].offset==Vector2(0,64),"completion preserves mirrored static idle")
    if actor=="vera" or neri_mirror or adela_mirror:check(not game.figures[index].flip_h,"network completion clears mirror")
    if (compact or elsbet_mirror) and app.idle_sequence_previews.has(actor) and app.map_sequence_enabled(actor):
        var idle=game.get_node("MapIdle");idle.set_process(true);idle.clocks[actor]=0.0
        var elapsed=0.0;var idle_replacements=0;runtime_id=game.battle.get_instance_id();until=Time.get_ticks_msec()+1400
        while Time.get_ticks_msec()<until:
            var clock=float(idle.clocks.get(actor,0.0))
            check(clock+.00001>=elapsed,"ordinary sync does not restart idle")
            elapsed=clock
            if runtime_id!=game.battle.get_instance_id():idle_replacements+=1;runtime_id=game.battle.get_instance_id()
            await process_frame
        check(elapsed>1.0 and idle_replacements>2,"idle persists across real sync replacements")
    print("NETWORK_WALK failures=",failures," actor=",actor," direction=",direction," samples=",samples," runtime_replacements=",replacements)
    app.session.transport.shutdown();quit(1 if failures else 0)
