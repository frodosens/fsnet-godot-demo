extends SceneTree
func _initialize():call_deferred("run")
func frames(n):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.presentation_preferences_path="user://three-idles-record.cfg";app.sfx_enabled=false
    for actor in ["neri","adela","elsbet"]:
        var data=preload("res://tests/walk_rear_fixture.gd").content(actor,"front_right")
        var i=0
        for j in range(data.units.size()):
            if data.units[j].id==actor:i=j
        app.new_game(data);change_scene_to_file("res://main.tscn");await frames(4)
        while not app.next_story().is_empty():app.advance_story(true)
        var g=current_scene;g.refresh();g.facing[actor]="front_right";g.selected=i;app.set_idle_sequence_preview(true,actor);g.refresh()
        var text=Style.label(actor+" · 仅新待机 / 移动保留原素材\n合法测试摆位 · 正常模拟速度",18);text.position=Vector2(320,96);text.mouse_filter=Control.MOUSE_FILTER_IGNORE;g.hud.root.add_child(text)
        await frames(310)
        assert(app.session.submit({"kind":"move","unit":i,"x":4,"y":8}))
        g.battle=app.session.logic;g.refresh()
        while g.motion.active():await process_frame
        await frames(100)
        for d in ["front_left","back_left","back_right"]:
            g.facing[actor]=d;g.refresh();await frames(120)
    print("THREE_IDLE_RECORD_COMPLETE normal_time=true old_motion=true");quit()
