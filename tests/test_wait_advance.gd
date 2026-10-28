extends SceneTree
var app
var game
var checks=0
const Runtime=preload("res://logic/runtime.gd")
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func frames(n=4):
    for i in range(n):await process_frame
func fresh(data={}):
    app.new_game(data if not data.is_empty() else preload("res://logic/content.gd").reference_content())
    change_scene_to_file("res://main.tscn");await frames(6);game=current_scene
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh();await frames()
func spend_all():
    for i in range(game.battle.units.size()):
        if game.battle.usable(i):check(app.session.submit({"kind":"wait","unit":i}),"authoritative setup Wait")
    game.refresh();game.skip_presentation();await frames()
func run():
    app=root.get_node("App");await fresh()
    check(game.wait_selected() and game.battle.step==1,"active Wait uses normal authority command")
    var before=game.battle.snapshot();var requests=app.session.request_id
    check(game.wait_selected() and game.selected==1,"exhausted actor advances in roster order")
    check(game.battle.snapshot()==before and app.session.request_id==requests,"selection neither fakes Wait nor advances RNG/step")
    check(not game.wait_selected() and game.battle.snapshot()==before,"rapid repeated Wait is suppressed after selection")
    await fresh()
    check(app.session.submit({"kind":"wait","unit":0}),"first actor spent")
    var destinations=game.battle.reachable(1);var destination=destinations.keys()[-1]
    check(app.session.submit({"kind":"move","unit":1,"x":destination.x,"y":destination.y}),"second actor actually moved")
    game.refresh();game.skip_presentation();await frames()
    check(game.battle.units[1].moves_used==game.battle.units[1].move_actions and not game.battle.units[1].acted,"second actor retains action")
    var round_before=game.battle.round_number
    check(game.wait_selected() and game.selected==1 and game.battle.round_number==round_before,"moved but actionable teammate is not skipped")
    await fresh();await spend_all()
    var step=game.battle.step;round_before=game.battle.round_number
    check(game.wait_selected(),"all spent auto End Turn accepted")
    check(game.battle.step==step+1 and game.battle.round_number==round_before+1,"exactly one normal End Turn")
    before=game.battle.snapshot();check(not game.wait_selected() and game.battle.snapshot()==before,"double touch cannot submit a second End Turn")
    check(not game.wait_selected() or not game.presentation_active(),"AI presentation blocks input")
    # Only the selected player's faction and living, controllable units qualify.
    var data=preload("res://logic/content.gd").reference_content()
    data.units[1].hp=1;data.units[3].x=2;data.units[3].y=8;data.units[3].movement=0;data.units[3].damage=10
    await fresh(data);check(app.session.submit({"kind":"end_turn"}),"real AI phase for dead-unit fixture")
    game.refresh();game.skip_presentation();await frames()
    check(game.battle.units[1].hp==0,"AI actually killed second teammate")
    check(app.session.submit({"kind":"wait","unit":0}),"first actor spent after AI")
    game.refresh();game.skip_presentation();await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh();game.skip_presentation();await frames()
    check(game.wait_selected() and game.selected==2,"dead actor and enemy AI are skipped")
    # Existing poll/authority queue protects an automatically generated End Turn.
    await fresh();await spend_all();step=game.battle.step
    app.session.pending=true
    check(game.wait_selected() and not game.queued_confirmation.is_empty() and game.battle.step==step,"auto End Turn queues behind pending poll")
    check(not game.wait_selected(),"repeat while queued rejected")
    game.flush_confirmation();check(game.battle.step==step,"queued command cannot overtake poll")
    app.session.pending=false;game.flush_confirmation()
    check(game.battle.step==step+1 and game.queued_confirmation.is_empty(),"queue emits one End Turn after poll")
    game.flush_confirmation();check(game.battle.step==step+1,"consumed queue cannot repeat")
    await fresh();await spend_all();step=game.battle.step
    app.session.command_pending=true
    check(not game.wait_selected() and game.battle.step==step,"inflight network command blocks Wait convenience")
    app.session.command_pending=false
    # Roundtrip an actual pre-existing save schema; rules and content hashes remain unchanged.
    app.save_root="user://mobile_wait_"+str(Time.get_ticks_usec())
    check(app.save_slot("slot1").is_empty(),"save with exhausted party")
    before=game.battle.snapshot();check(app.load_slot("slot1"),"load existing save schema")
    change_scene_to_file("res://main.tscn");await frames(6);game=current_scene
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh();check(game.battle.snapshot()==before,"save/load preserves authoritative state")
    check(game.wait_selected() and game.battle.step==step+1,"loaded spent party can auto End Turn")
    print("WAIT_ADVANCE checks=",checks," failures=0")
    quit()
