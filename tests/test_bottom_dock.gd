extends SceneTree
var checks=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func frames():
    for i in range(5):await process_frame
func click(button):
    for pressed in [true,false]:
        var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=button.get_global_rect().get_center();e.pressed=pressed;root.push_input(e,true);await process_frame
    await frames()
func run():
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();var hud=game.hud;var dock=hud.dock
    for viewport in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=viewport;await frames()
        for kind in ["move","attack","skill","item","wait"]:
            var b=dock.action_nodes[kind];var rect=b.get_global_rect()
            check(rect.position.x>=0 and rect.end.x<=root.get_visible_rect().size.x and rect.end.y<=root.get_visible_rect().size.y,"buttons fit viewport")
            var expected=dock.layout.action_rects[kind]
            check(b.position==Vector2(expected[0],expected[1]) and b.size==Vector2(expected[2],expected[3]),"measured button geometry")
        check(dock.canvas.scale.x==dock.canvas.scale.y,"no nonuniform scaling")
    var initial=game.battle.snapshot()
    await click(dock.action_nodes.move);check(dock.context.visible and not dock.actions.visible,"move replaces dock")
    check(dock.confirm.disabled,"no destination cannot confirm")
    game.stage_move(Vector2i(4,4));await frames();check(not dock.confirm.disabled and game.battle.snapshot()==initial,"selection only previews")
    await click(dock.cancel);check(game.battle.snapshot()==initial and dock.actions.visible,"cancel returns without cost")
    await click(dock.action_nodes.move);game.stage_move(Vector2i(4,4));await frames();await click(dock.confirm)
    check(game.battle.step==1,"actual confirm button sends one command")
    game.skip_presentation();await frames();await click(dock.action_nodes.wait)
    check(game.battle.step==2 and game.battle.units[0].acted,"actual Wait only ends selected unit")
    check(game.battle.round_number==1 and not game.battle.units[1].acted,"Wait is not End Turn")
    check(not dock.action_nodes.wait.is_visible_in_tree() or dock.action_nodes.wait.disabled,"spent wait disabled")
    print("BOTTOM_DOCK checks=",checks," failures=0")
    quit()
