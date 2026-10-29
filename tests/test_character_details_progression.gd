extends "res://tests/support/test_case.gd"
const Runtime=preload("res://logic/runtime.gd")
const Model=preload("res://ui/character_details_model.gd")
func _initialize():call_deferred("run")
func frames():
    for i in range(4):await process_frame
func run():
    var app=root.get_node("App");var model=Model.new();var content=preload("res://logic/content.gd").reference_content()
    check(not model.progression({}).available,"missing fields not invented")
    for xp in [0,59,60,149,150,1620]:
        var campaign={"roster":[{"id":"mara","xp":xp}],"completed":[]}
        app.new_game(content,campaign);change_scene_to_file("res://main.tscn");await frames();var game=current_scene
        while not app.next_story().is_empty():app.advance_story(true)
        game.refresh();game.hud.show_character_details();await frames();var page=game.hud.modal;var u=game.battle.units[0];var growth=model.progression(u)
        check(growth.available and growth.total==xp,"actual XP displayed")
        check(growth.current==xp-u.xp_floor and growth.required==u.xp_next-u.xp_floor,"progress relative to actual thresholds")
        check(page.level_label.text=="Lv."+str(u.level),"actual level label")
        check(page.xp_group.visible and page.xp_bar.value==(page.xp_bar.max_value if xp==1620 else growth.current),"real XP fill with cap guard")
        check(page.summary.text.contains("已满级") if xp==1620 else page.summary.text.contains("经验 %d / %d"%[growth.current,growth.required]),"progress/cap readable text")
        var snapshot=game.battle.snapshot();var preview=model.preview_equipment(game.battle,0,6,4)
        var replica=Runtime.new(content);check(replica.restore(snapshot),"grown snapshot restores for comparison")
        check(replica.apply_command({"kind":"equip","unit":0,"slot":6,"item":4,"step":1}),"grown legal equipment command")
        for change in preview.changes:check(replica.units[0][change.key]==change.after,"preview retains level-derived stats")
        check(game.battle.snapshot()==snapshot and game.battle.units[0].xp==xp,"preview cannot change XP/current state")
        game.hud.clear_modal();await frames()
    current_scene.queue_free();await frames();print("CHARACTER_DETAILS_PROGRESSION checks=",checks," failures=",failures);quit(0 if failures==0 else 1)
