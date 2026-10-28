extends "res://tests/test_mobile_touch_camera.gd"
func settle_focus():
    await create_timer(0.35).timeout;await frames()
func run():
    app=root.get_node("App");app.mobile_presentation=true;Input.emulate_mouse_from_touch=true
    for physical in [Vector2i(2400,1080),Vector2i(1280,800),Vector2i(1600,1200)]:
        root.size=physical;await frames();await fresh()
        var before=game.battle.snapshot();var ui=game.hud.dock.canvas.global_position
        await tap(cell(game.battle.units[1].pos));check(game.selected==1,"manual map selection")
        check(game.mode=="move" and not game.hud.action_menu_open,"selecting actor arms movement without Move button")
        check(game.pending_move.is_empty() and game.battle.snapshot()==before,"selecting actor never submits")
        await settle_focus()
        check(game.scene_view.pan.is_equal_approx(game.scene_view.focus_pan()),"camera reaches nearest bounded actor center")
        check(game.scene_view.pan.abs().x<=game.scene_view.pan_limit.x+0.001 and game.scene_view.pan.abs().y<=game.scene_view.pan_limit.y+0.001,"camera center clamps")
        check(game.hud.dock.canvas.global_position==ui,"camera does not shift UI")
        var destination=Vector2i(2,8)
        await tap(cell(destination));check(not game.pending_move.is_empty() and game.battle.step==0,"next tap previews legal movement")
        check(game.ground_overlay.focus_marker().get("cell")==destination and game.ground_overlay.focus_marker().valid,"selected destination marker")
        await tap(cell(destination));check(game.battle.step==1,"second tap confirms once")
        game.skip_presentation();await frames()
        # A used-up movement budget must not be rearmed by repeated selection.
        check(game.select_actor(1),"spent mover still selectable")
        check(game.hud.action_menu_open,"no movement mode when no legal move remains")
        var settled=game.scene_view.pan
        game.refresh();await frames();check(not game.scene_view.focus_active and game.scene_view.pan==settled,"refresh does not recenter same actor")
        await fresh();check(game.select_actor(1),"roster selection entry point");await frames(1)
        var center=root.get_visible_rect().size*Vector2(0.55,0.4)
        await drag(center,center+Vector2(60,75));var dragged=game.scene_view.pan
        await settle_focus();check(not game.scene_view.focus_active and game.scene_view.pan==dragged,"user drag permanently interrupts focus")
        check(game.pending_move.is_empty() and game.battle.step==0,"focus and drag never submit")
        game.session.pending=true;var selected=game.selected
        check(not game.select_actor(2) and game.selected==selected,"pending network blocks actor selection")
        game.session.pending=false
        check(not game.select_actor(3),"enemy not controllable")
        game.select_actor(2);game.select_mode("ability:ember");await frames()
        check(game.mode=="ability:ember","explicit skill choice wins over automatic move")
        game.hud.cancel_targeting();game.select_actor(0);await settle_focus()
        check(game.mode=="move" and not game.hud.action_menu_open,"switching from skills enters movement")
        check(game.wait_selected(),"normal Wait");await frames()
        check(game.wait_selected(),"exhausted Wait advances");await settle_focus()
        check(game.selected==1 and not game.hud.action_menu_open,"Wait auto-next arms movement")
        # Replacement runtime with unchanged state must not restart the camera.
        var replacement=preload("res://logic/runtime.gd").new(game.battle.content)
        check(replacement.restore(game.battle.snapshot()),"poll replacement fixture")
        game.session.logic=replacement;await frames()
        check(not game.scene_view.focus_active,"identical runtime replacement does not recenter")
    # Real rule-driven death and next-turn fallback, followed by save restore.
    var data=preload("res://logic/content.gd").reference_content()
    data.units[0].hp=1;data.units[3].x=4;data.units[3].y=6;data.units[3].damage=30
    await fresh(data)
    check(game.session.submit({"kind":"end_turn"}),"validated next turn")
    await frames();game.skip_presentation();await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    await settle_focus()
    check(game.battle.units[0].hp==0 and game.selected!=0 and game.battle.usable(game.selected),"dead actor fallback selects living player")
    check(not game.hud.action_menu_open and game.mode=="move","next turn arms legal movement after presentation")
    var saved=game.battle.snapshot();var replacement=preload("res://logic/runtime.gd").new(game.battle.content)
    check(replacement.restore(saved),"checkpoint state restores")
    game.session.logic=replacement;game.refresh();await frames()
    check(game.battle.snapshot()==saved and not game.scene_view.focus_active,"checkpoint refresh no new command or camera restart")
    # Extreme targets and resize remain within the authored pan bounds.
    for point in [Vector3(-100,0,-100),Vector3(100,0,100)]:
        game.scene_view.focus_actor(point);root.size=Vector2i(2400,1080);await settle_focus()
        check(game.scene_view.pan.abs().x<=game.scene_view.pan_limit.x+0.001 and game.scene_view.pan.abs().y<=game.scene_view.pan_limit.y+0.001,"edge focus and resize clamp")
    print("SELECTION_CAMERA checks=",checks," failures=0 synthetic_touch=true");quit()
