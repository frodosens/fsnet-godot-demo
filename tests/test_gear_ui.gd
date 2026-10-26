extends SceneTree
var checks=0
var failures=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func frames():
    await process_frame
    await process_frame
func run():
    var app=root.get_node("App");app.new_game()
    var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
    await frames();game.hud.advance(true)
    game.hud.gear_slot=5;game.hud.show_gear();await frames()
    check(game.hud.modal.get_child(0).get_rect().end.y<=800,"gear panel fits base viewport")
    game.hud.equip_item(2);await frames()
    check(game.battle.units[0].move_actions==2,"gear UI submits real command")
    game.hud.clear_modal();game.selected=2;game.hud.show_abilities();await frames()
    check(is_instance_valid(game.hud.modal),"data-driven skill picker opens")
    game.hud.choose_ability("focus_bolt")
    check(game.mode=="ability:focus_bolt" and not game.hud.blocks_input(),"skill picker returns targeting input")
    game.hud.show_items();await frames();game.hud.choose_item("bandage")
    check(game.mode=="item:bandage" and not game.hud.blocks_input(),"item picker returns targeting input")
    print("GEAR_UI_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
