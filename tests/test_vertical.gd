extends SceneTree
const Content=preload("res://logic/content.gd")
var app
var failures=0
var checks=0
func check(value,label):
    checks+=1
    if not value:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
    app=root.get_node("App")
    app.save_root="user://test_saves_"+str(Time.get_ticks_usec())
    app.new_game()
    check(app.session.logic.units.size()==6,"new game")
    var first=app.next_story()
    check(first.id=="ch01_intro" and first.index==1,"intro trigger")
    var before=app.session.logic.state_hash()
    app.advance_story(false)
    check(app.next_story().index==2 and before==app.session.logic.state_hash(),"local dialogue cursor never changes shared hash")
    check(app.save_slot("slot1")=="","save during dialogue")
    app.advance_story(true)
    check(app.session.submit({"kind":"move","unit":0,"x":3,"y":5}),"command after dialogue")
    check(app.load_slot("slot1") and app.session.logic.step==0 and app.next_story().index==2,"load restores rules/RNG/step and exact line")
    app.advance_story(true)
    var scene=load("res://main.tscn").instantiate();root.add_child(scene)
    await process_frame
    check(not scene.hud.story_panel.visible,"completed intro releases gameplay input")
    var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=scene.camera.unproject_position(Vector3(3,0,5))
    scene._unhandled_input(click)
    check(app.session.logic.step==1,"scene click executes shared rule")
    scene.hud.toggle_pause()
    var snapshot=app.session.logic.snapshot();scene.finish_turn()
    check(app.session.logic.snapshot()==snapshot,"pause modal blocks battle commands")
    scene.hud.clear_modal();scene.finish_turn()
    check(app.session.logic.round_number==2 and app.next_story().id=="ch01_mid_debt","round condition emits stable event")
    var saved=app.session.logic.state_hash()
    check(app.save_slot("slot3")=="","save in battle")
    check(app.load_slot("slot3") and app.session.logic.state_hash()==saved,"battle state and RNG restore")
    var broken=FileAccess.open(app.save_path("slot2"),FileAccess.WRITE);broken.store_string("{bad");broken.close()
    check(not app.inspect_slot("slot2").error.is_empty(),"corrupt save feedback")
    check(not app.load_slot("slot2") and app.session.logic.state_hash()==saved,"corrupt load leaves running state untouched")
    var data=Content.default_content();data.id="../escape"
    check(not Content.validate(data).is_empty(),"mod traversal ID rejected")
    data=Content.default_content();data.units[0].x=-1
    check(not Content.validate(data).is_empty(),"mod spawn bounds")
    data=Content.default_content();data.story.events[0].lines[0].speaker="missing"
    check(not Content.validate(data).is_empty(),"story reference validation")
    # Force no gameplay outcomes: pass normally until defeat, then display the ending.
    app.new_game();app.advance_story(true)
    for i in range(60):
        if app.session.logic.outcome!="playing":break
        app.session.submit({"kind":"end_turn"})
    check(app.session.logic.outcome=="defeat" and app.next_story().id=="ch01_defeat","defeat ending has priority over unseen mid-scenes")
    app.new_game()
    check(app.next_story().id=="ch01_intro" and app.presentation.seen.is_empty(),"new game resets presentation")
    scene.queue_free();await process_frame
    print("VERTICAL_TESTS checks=",checks," failures=",failures," isolated_save_root=",app.save_root)
    quit(0 if failures==0 else 1)
