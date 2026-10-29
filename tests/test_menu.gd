extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames():
    await process_frame
    await process_frame
func run():
    var app=root.get_node("App");app.save_root="user://menu_tests_"+str(Time.get_ticks_usec())
    var menu=load("res://ui/menu.tscn").instantiate();root.add_child(menu);current_scene=menu
    await frames()
    check(menu.page.get_child(1).has_focus(),"new game keyboard focus")
    menu.show_load()
    check(menu.page.get_child(1).get_child(0).get_child(0).disabled,"empty save disabled")
    menu.show_network();menu.token_edit.text="short";menu.begin_room(false)
    check(not menu.busy and menu.network_status.text.contains("16"),"invalid room token feedback")
    menu.show_home();menu.request_exit();var dialog=menu.exit_dialog;menu.request_exit()
    check(menu.exit_dialog==dialog,"repeated exit does not stack dialogs")
    dialog.canceled.emit();await frames()
    menu.start_new();var session=app.session;menu.start_new()
    check(app.session==session,"repeated start does not create another game")
    await frames()
    var game=current_scene
    check(game is Node3D and game.hud.story_panel.visible,"menu to playable story scene")
    game.finish_turn();check(app.session.logic.step==0,"story blocks battle input")
    game.hud.advance(true);game.finish_turn()
    check(app.session.logic.step==1,"gameplay resumes after story")
    game.hud.save_and_leave(false);await frames()
    check(current_scene is Control and app.session==null,"save and return disposes live battle")
    current_scene.show_load();current_scene.load_selected("auto");await frames()
    check(current_scene is Node3D and app.session.logic.step==1,"menu load restores exact battle")
    print("MENU_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
