extends "res://tests/support/test_case.gd"
const Arc=preload("res://ui/action_arc.gd")
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func run():
    for view in [Vector2(1280,800),Vector2(960,600),Vector2(1920,1080)]:
        for point in [Vector2(50,130),Vector2(view.x-50,130),Vector2(50,view.y-100),view-Vector2(50,100),view/2]:
            var keepout=Rect2(point-Vector2(46,65),Vector2(92,110));var plan=Arc.solve(point,view,keepout)
            for p in plan.positions:
                var rect=Arc.visual_rect(p)
                require(not rect.intersects(keepout),"edge layout avoids actor")
                require(rect.position.x>=19.9 and rect.end.x<=view.x-19.9 and rect.position.y>=79.9 and rect.end.y<=view.y-69.9,"arc fully within safe viewport")
    root.size=Vector2i(1280,800)
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();await frames();var hud=game.hud;var before=game.battle.snapshot()
    require(hud.action_panel.visible and hud.arc_actor_id=="mara","arc attached to selected actor")
    hud.focus_arc_choice("attack");await create_timer(.2).timeout
    require(is_equal_approx(hud.action_buttons.attack.selection_shift,-14) and is_zero_approx(hud.action_buttons.move.selection_shift),"selected left slide and previous return")
    require(is_equal_approx(hud.action_buttons.attack.scale.x,1.0) and is_equal_approx(hud.action_buttons.move.scale.x,0.85),"selected normal scale, other items smaller")
    app.reduced_motion=true;hud.focus_arc_choice("item");await frames()
    require(is_equal_approx(hud.action_buttons.item.scale.x,1.0) and is_equal_approx(hud.action_buttons.item.selection_shift,-14),"reduced motion settles selection without animation")
    app.reduced_motion=false
    var anchor=hud.arc_layout.anchor;game.camera.position.x+=.2;await frames()
    require(hud.arc_layout.anchor!=anchor,"projection follows camera")
    hud.select_hero(1);await frames();require(hud.arc_actor_id=="finn","reselection discards old attachment")
    hud.select_hero(0);await frames();hud.choose_action("move");game.update_move_preview(Vector2i(4,4));hud.refresh()
    require(not hud.action_panel.visible and game.preview_path.size()==4,"move selection hides arc and keeps authoritative path")
    hud.cancel_targeting();await frames();require(hud.action_panel.visible and game.preview_path.is_empty() and game.battle.snapshot()==before,"cancel restores arc without command")
    hud.choose_action("move");var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=game.camera.unproject_position(Vector3(4,0,6));root.push_input(click,true);await frames()
    require(game.battle.step==0 and not game.pending_move.is_empty(),"target click only stages move")
    require(game.confirm_move() and game.battle.step==1,"explicit confirm executes move")
    game.skip_presentation();await frames();require(hud.action_panel.visible and hud.action_buttons.move.disabled,"completion restores arc with legible disabled move")
    print("ACTOR_ARC checks=",checks," failures=0")
    quit()
