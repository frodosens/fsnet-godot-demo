extends SceneTree
var failures=0
func check(ok,label):
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App")
    var data=preload("res://logic/content.gd").reference_content();data.units[1].x=1;data.units[1].y=8
    check(app.start_room(false,int(OS.get_environment("AMBER_TEST_PORT")),OS.get_environment("AMBER_TOKEN"),data),"connect real authority")
    var deadline=Time.get_ticks_msec()+15000
    while not app.session.ready or app.session.pending:
        await process_frame
        if Time.get_ticks_msec()>deadline:check(false,"connect timeout");quit(1);return
    change_scene_to_file("res://main.tscn");await process_frame;await process_frame
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.motion.speed=.5
    while app.session.pending:await process_frame
    check(app.session.submit({"kind":"move","unit":1,"x":4,"y":8}),"network legal Finn move")
    while game.battle.step<1:
        await process_frame
        if Time.get_ticks_msec()>deadline:check(false,"command timeout");quit(1);return
    var truth=game.battle.snapshot();var previous=0.0;var replacements=0;var runtime_id=game.battle.get_instance_id();var poses={};var samples=0
    while game.motion.active():
        var distance=game.motion.motions.finn.travelled
        check(distance+.00001>=previous,"ordinary sync never restarts travel")
        previous=distance;samples+=1
        if runtime_id!=game.battle.get_instance_id():replacements+=1;runtime_id=game.battle.get_instance_id()
        var clip=game.motion.walk_library.clips["finn:front_right"]
        poses[clip.textures.find(game.figures[1].texture)]=true
        check(game.battle.snapshot()==truth,"poll keeps authoritative state")
        await process_frame
        if Time.get_ticks_msec()>deadline:check(false,"motion timeout");break
    check(replacements>=2 and samples>20,"real runtime replacements observed during walk")
    check(poses.has(1) and poses.has(3),"real sync allows both stride poses")
    check(game.figures[1].position==Vector3(4,0,8),"network authoritative endpoint")
    var final_texture=game.directional_idle_texture(1,"front_right")
    game.get_node("MapIdle").set_process(false);game.figures[1].texture=final_texture
    var until=Time.get_ticks_msec()+500
    while Time.get_ticks_msec()<until:await process_frame
    check(not game.motion.active(),"post-completion polls don't replay")
    print("NETWORK_WALK failures=",failures," samples=",samples," runtime_replacements=",replacements)
    app.session.transport.shutdown();quit(1 if failures else 0)
