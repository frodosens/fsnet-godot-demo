extends SceneTree
var checks=0
func check(ok,label):
    checks+=1
    if not ok:push_error(label);quit(1);assert(ok,label)
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.load_presentation_preferences()
    var d=preload("res://logic/content.gd").from_file(OS.get_environment("AMBER_MOD")).data
    check(app.start_room(false,int(OS.get_environment("AMBER_TEST_PORT")),OS.get_environment("AMBER_TOKEN"),d),"connect")
    var deadline=Time.get_ticks_msec()+15000
    while not app.session.ready or app.session.pending:
        await process_frame
        if Time.get_ticks_msec()>deadline:push_error("connect timeout");quit(1);return
    change_scene_to_file("res://main.tscn");await process_frame;await process_frame
    var g=current_scene;g.refresh();g.motion.speed=.15
    var other=g.battle.units[1].duplicate(true)
    while app.session.pending:await process_frame
    check(app.session.submit({"kind":"move","actor_id":"custom_guard_0","x":2,"y":6}),"legal stable-ID move")
    while g.battle.step<1:
        await process_frame
        if Time.get_ticks_msec()>deadline:push_error("move timeout");quit(1);return
    var runtime_id=g.battle.get_instance_id();var replacements=0;var distance=0.0
    while g.motion.active():
        check(g.motion.motions.has("custom_guard_0") and not g.motion.motions.has("custom_guard_1"),"one actor clock")
        var current=g.motion.motions.custom_guard_0.travelled
        check(current>=distance,"poll never resets phase");distance=current
        check(g.battle.units[1]==other,"other template instance state isolated")
        if g.battle.get_instance_id()!=runtime_id:replacements+=1;runtime_id=g.battle.get_instance_id()
        await process_frame
        if Time.get_ticks_msec()>deadline:push_error("motion timeout");quit(1);return
    check(replacements>=10,"multiple real sync replacements")
    check(g.battle.units[0].pos==Vector2i(2,6) and g.battle.units[1].pos==Vector2i(4,6),"independent settled positions")
    g.skip_presentation();app.close_room();current_scene.queue_free();await process_frame;await process_frame
    print("NETWORK_UNIT_INSTANCES checks=",checks," replacements=",replacements," failures=0");quit()
