extends SceneTree
const Stats=preload("res://tests/perf_stats.gd")
var results={}
var game
func _initialize():call_deferred("run")
func frames(n):
    for i in range(n):await process_frame
func fresh(online=false):
    var app=root.get_node("App");var data=preload("res://tests/walk_rear_fixture.gd").content("mara","back_left")
    if online:
        assert(app.start_room(true,int(OS.get_environment("PERF_PORT")) if not OS.get_environment("PERF_PORT").is_empty() else 28791,"performance-local-test",data))
        while not app.session.ready:await process_frame
    else:app.new_game(data)
    change_scene_to_file("res://main.tscn");await frames(8)
    while not app.next_story().is_empty():app.advance_story(true)
    game=current_scene;game.refresh();await frames(20)
func measure(name,count):
    Stats.samples={};Stats.enabled=true
    var last=Time.get_ticks_usec();var start_frame=Engine.get_process_frames();var start=last
    for i in range(count):
        await process_frame
        var now=Time.get_ticks_usec();Stats.record("frame_interval",now-last);last=now
        Stats.record("engine_process",Performance.get_monitor(Performance.TIME_PROCESS)*1000000)
        if name=="path_hover":game.update_move_preview(Vector2i(2+(i/10)%2,8))
    Stats.enabled=false
    results[name]={"metrics":Stats.summary(),"elapsed_seconds":(Time.get_ticks_usec()-start)/1000000.0,"frames":Engine.get_process_frames()-start_frame,"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}
func run():
    root.size=Vector2i(1280,800);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    await fresh();game.selected=-1;game.refresh();await measure("idle",120)
    game.selected=0;game.hud.action_menu_open=true;game.refresh();await measure("selected",120)
    game.hud.choose_action("move");game.update_move_preview(Vector2i(2,8));await measure("path_hover",120)
    await fresh();assert(root.get_node("App").session.submit({"kind":"move","unit":0,"x":1,"y":8}));game.battle=root.get_node("App").session.logic;game.refresh();await measure("movement",60)
    await fresh(true);await measure("online_sync",180)
    results["environment"]={"version":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"viewport":str(root.size),"movie":OS.has_feature("movie"),"fixed_fps_arg":OS.get_cmdline_args().has("--fixed-fps")}
    FileAccess.open(OS.get_environment("PERF_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
    root.get_node("App").close_room();quit()
