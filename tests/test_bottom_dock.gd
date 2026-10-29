extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames():
    for i in range(5):await process_frame
func click(button):
    for pressed in [true,false]:
        var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=button.get_global_rect().get_center();e.pressed=pressed;root.push_input(e,true);await process_frame
    await frames()
func run():
    var app=root.get_node("App");app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();var hud=game.hud;var dock=hud.dock
    for viewport in [Vector2i(1280,800),Vector2i(960,600),Vector2i(1280,720)]:
        root.size=viewport;await frames()
        for kind in ["move","attack","skill","item","wait"]:
            var b=dock.action_nodes[kind];var rect=b.get_global_rect()
            require(rect.position.x>=0 and rect.end.x<=root.get_visible_rect().size.x and rect.end.y<=root.get_visible_rect().size.y,"buttons fit viewport")
            var expected=dock.layout.action_rects[kind]
            require(b.position==Vector2(expected[0],expected[1]) and b.size==Vector2(expected[2],expected[3]),"measured button geometry")
        require(dock.canvas.scale.x==dock.canvas.scale.y,"no nonuniform scaling")
        for control in [dock.confirm,dock.cancel]:
            var caption=control.get_meta("caption")
            var text_width=caption.get_theme_font("font").get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,caption.get_theme_font_size("font_size")).x
            require(caption.position.x+text_width<=control.size.x-12,"horizontal caption fits painted frame padding")
            require(caption.size.x>=text_width,"Chinese caption not clipped")
    var initial=game.battle.snapshot()
    await click(dock.action_nodes.move);require(dock.context.visible and dock.actions.visible,"move retains directly switchable commands")
    require(dock.confirm.disabled,"no destination cannot confirm")
    game.stage_move(Vector2i(4,4));await frames();require(not dock.confirm.disabled and game.battle.snapshot()==initial,"selection only previews")
    await click(dock.cancel);require(game.battle.snapshot()==initial and dock.actions.visible,"cancel returns without cost")
    await click(dock.action_nodes.move);game.stage_move(Vector2i(4,4));await frames();await click(dock.confirm)
    require(game.battle.step==1,"actual confirm button sends one command")
    game.skip_presentation();await frames();await click(dock.action_nodes.wait)
    require(game.battle.step==2 and game.battle.units[0].acted,"actual Wait only ends selected unit")
    require(game.battle.round_number==1 and not game.battle.units[1].acted,"Wait is not End Turn")
    require(not dock.action_nodes.wait.disabled,"spent Wait remains available to advance actor")
    await click(dock.action_nodes.wait)
    require(game.selected==1 and game.battle.step==2,"spent Wait selects next unit without extra command")
    print("BOTTOM_DOCK checks=",checks," failures=0")
    quit()
