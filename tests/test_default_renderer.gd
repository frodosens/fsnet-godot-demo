extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames():
    for i in range(4):await process_frame
func run():
    var app=root.get_node("App");app.save_root="user://default_renderer_"+str(Time.get_ticks_usec())
    check(app.scene_renderer=="auto","fresh process chooses automatic authored scene")
    change_scene_to_file("res://ui/menu.tscn");await frames()
    var button=current_scene.page.get_child(1)
    for down in [true,false]:
        var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=button.get_global_rect().get_center();e.pressed=down;root.push_input(e,true);await process_frame
    await frames()
    var game=current_scene
    check(game is Node3D and game.scene_view.active,"real New Game click opens illustrated scene without capture override")
    check(game.scene_view.shadows.size()==6 and game.scene_view.painted_lights.size()==4 and game.figures[0].shaded,"default keeps lights, shaded actors and contact shadows")
    var snapshot=game.battle.snapshot()
    check(app.save_slot("slot1")=="","save compatible scene")
    check(app.load_slot("slot1"),"load existing format without renderer field")
    change_scene_to_file("res://main.tscn");await frames()
    check(current_scene.scene_view.active and current_scene.battle.snapshot()==snapshot,"loaded authored scene automatically uses painting without rules changes")
    app.scene_renderer="three_d";change_scene_to_file("res://main.tscn");await frames()
    check(not current_scene.scene_view.active,"deliberate 3D choice respected")
    app.load_slot("slot1");change_scene_to_file("res://main.tscn");await frames()
    check(not current_scene.scene_view.active,"load does not overwrite explicit session preference")
    app.scene_renderer="auto";var data=Content.reference_content();data.terrain[0]="G"+data.terrain[0].substr(1)
    app.new_game(data);change_scene_to_file("res://main.tscn");await frames()
    check(not current_scene.scene_view.active,"modified terrain falls back to 3D")
    app.new_game(Content.default_content());change_scene_to_file("res://main.tscn");await frames()
    check(not current_scene.scene_view.active,"legacy incompatible map stays 3D")
    print("DEFAULT_RENDERER checks=",checks," failures=",failures);quit(1 if failures else 0)
