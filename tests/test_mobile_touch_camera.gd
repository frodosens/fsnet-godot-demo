extends SceneTree
var checks=0
var app
var game
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func frames(n=4):
    for i in range(n):await process_frame
func send_touch(pos,down,index=0,canceled=false):
    var e=InputEventScreenTouch.new();e.index=index;e.position=root.get_final_transform()*pos;e.pressed=down;e.canceled=canceled
    Input.parse_input_event(e);Input.flush_buffered_events();await frames(2)
func tap(pos):
    await send_touch(pos,true);await send_touch(pos,false);await frames()
func drag(a,b,index=0):
    await send_touch(a,true,index)
    for i in range(1,5):
        var e=InputEventScreenDrag.new();e.index=index;e.position=root.get_final_transform()*a.lerp(b,i/4.0);e.relative=root.get_final_transform().basis_xform((b-a)/4.0)
        Input.parse_input_event(e);Input.flush_buffered_events();await frames(2)
    await send_touch(b,false,index);await frames()
func fresh(data={}):
    app.new_game(data if not data.is_empty() else preload("res://logic/content.gd").reference_content())
    change_scene_to_file("res://main.tscn");await frames(6);game=current_scene
    while not app.next_story().is_empty():app.advance_story(true)
    game.refresh();await frames()
func cell(pos):return game.camera.unproject_position(Vector3(pos.x,0,pos.y))
func button(b):
    check(b.is_visible_in_tree() and not b.disabled,"touch target enabled")
    await tap(b.get_global_rect().get_center())
func run():
    app=root.get_node("App");app.mobile_presentation=true;Input.emulate_mouse_from_touch=true
    for physical in [Vector2i(1920,1080),Vector2i(2400,1080),Vector2i(2560,1440),Vector2i(1600,1200)]:
        root.size=physical;app.safe_area_override=Rect2i(48,20,physical.x-72,physical.y-36);await frames()
        await fresh()
        var hud=game.hud;var dock=hud.dock;var view=root.get_visible_rect().size;var safe=app.ui_safe_rect()
        var before=game.battle.snapshot();var original_ui=dock.action_nodes.wait.get_global_rect().size
        for b in [dock.action_nodes.move,dock.action_nodes.wait,hud.turn_button,hud.pause_button]:
            check(safe.encloses(b.get_global_rect()),"controls within safe area "+str(physical))
        check(game.scene_view.art_rect.size==view,"scene covers viewport without blue side gutters")
        check(is_equal_approx(game.camera.size*view.x/view.y,game.scene_view.saved_size*1.6) or is_equal_approx(game.camera.size,game.scene_view.saved_size),"uniform camera cover")
        var center=view*Vector2(0.55,0.4)
        await drag(center,center+Vector2(90,160))
        check(game.battle.snapshot()==before,"diagonal drag cannot submit or spend")
        check(game.pending_move.is_empty() and game.pending_target.is_empty(),"drag cancels target proposal")
        check(dock.action_nodes.wait.get_global_rect().size.is_equal_approx(original_ui),"pan never scales HUD")
        game.scene_view.pan_by(Vector2(100000,100000));await frames()
        check(game.scene_view.pan.abs().x<=game.scene_view.pan_limit.x+0.001 and game.scene_view.pan.abs().y<=game.scene_view.pan_limit.y+0.001,"pan clamps at map edge")
        game.scene_view.pan_by(Vector2(-200000,-200000));await frames()
        check(game.scene_view.pan.abs().x<=game.scene_view.pan_limit.x+0.001 and game.scene_view.pan.abs().y<=game.scene_view.pan_limit.y+0.001,"opposite edge clamps")
        game.scene_view.pan=Vector2.ZERO;game.scene_view.fit();await frames()
        # GUI drag must not pan or activate its button; release outside it.
        var camera_pos=game.camera.position
        await drag(dock.action_nodes.wait.get_global_rect().get_center(),center)
        check(game.camera.position.is_equal_approx(camera_pos) and game.battle.snapshot()==before,"GUI-origin drag cannot pan or Wait")
        await drag(center,center+Vector2(0,80),1)
        check(game.camera.position.is_equal_approx(camera_pos) and game.battle.snapshot()==before,"secondary finger ignored safely")
        await send_touch(center,true);await send_touch(center,false,0,true)
        check(game.battle.snapshot()==before,"canceled touch cannot submit")
        # Pick through the actual moved camera, then use raw touch+emulated mouse on Wait.
        game.scene_view.pan_by(Vector2(0,-150));await frames()
        var point=cell(game.battle.units[0].pos)
        check(game.mouse_cell(point)==game.battle.units[0].pos,"inverse pick after zoom/pan")
        await tap(point);check(game.selected==0,"tap after pan selects actor")
        await button(dock.cancel) # Selection now defaults to Move; return to commands for Wait.
        await button(dock.action_nodes.wait)
        check(game.battle.step==1 and game.battle.units[0].acted and game.battle.units[0].moves_used==game.battle.units[0].move_actions,"Wait commits exactly once")
        check(game.battle.round_number==1 and not game.battle.units[1].acted,"Wait ends selected unit, not entire turn")
        check(not dock.action_nodes.wait.disabled and dock.notice.text.contains("点待机切换队员"),"exhausted Wait remains actionable with explicit hint")
        await tap(dock.action_nodes.wait.get_global_rect().get_center());check(game.battle.step==1 and game.selected==1,"spent Wait selects next actor without command")
        await tap(dock.action_nodes.wait.get_global_rect().get_center());check(game.battle.step==1 and game.selected==1,"rapid duplicate touch cannot spend the next actor")
        print("MOBILE_VIEWPORT ",physical," safe=",safe," ui=",original_ui)
    # Full raw-touch menu -> new game -> select -> Wait -> advance -> End Turn.
    root.size=Vector2i(2400,1080);app.safe_area_override=Rect2i(48,20,2328,1044)
    change_scene_to_file("res://ui/menu.tscn");await frames(6)
    var menu=current_scene
    await button(menu.page.get_child(1));await frames(8);game=current_scene
    check(game is Node3D,"touch New Game enters battlefield")
    while not app.next_story().is_empty():
        var skipped=false
        for b in game.hud.story_panel.find_children("*","Button",true,false):
            if b.text.begins_with("跳过"):await button(b);skipped=true;break
        check(skipped,"touch story skip is available")
    game.refresh();await frames()
    game.scene_view.pan_by(Vector2(0,-150));await frames()
    await tap(cell(game.battle.units[0].pos));check(game.selected==0,"touch select after New Game")
    for i in range(3):
        check(game.selected==i,"stable own-team advance order")
        if not game.hud.action_menu_open:await button(game.hud.dock.cancel)
        await button(game.hud.dock.action_nodes.wait)
        check(game.battle.units[i].acted,"touch Wait spends selected actor")
        await button(game.hud.dock.action_nodes.wait)
        if i<2:
            check(game.selected==i+1,"spent touch Wait advances without end turn")
            await create_timer(0.36).timeout
    check(game.battle.round_number==2 and game.battle.step==4,"last spent touch Wait sends one End Turn")
    var after_round=game.battle.snapshot()
    await tap(game.hud.dock.action_nodes.wait.get_global_rect().get_center())
    check(game.battle.snapshot()==after_round,"double touch after auto End Turn cannot spend a new-round unit")
    # Move proposal remains a two-tap workflow after a pan; no OS double-click requirement.
    root.size=Vector2i(2400,1080);app.safe_area_override=Rect2i();await frames();await fresh()
    await button(game.hud.dock.action_nodes.move)
    var target=Vector2i(4,4);await tap(cell(target));check(not game.pending_move.is_empty() and game.battle.step==0,"first touch only previews")
    var center=root.get_visible_rect().size*Vector2(0.55,0.4)
    await drag(center,center+Vector2(30,80));check(game.pending_move.is_empty() and game.battle.step==0,"drag during preview cancels without command")
    await tap(cell(target));check(not game.pending_move.is_empty() and game.battle.step==0,"first post-drag tap previews")
    await tap(cell(target));check(game.battle.step==1 and game.battle.units[0].pos==target,"second post-drag tap confirms exactly once")
    game.skip_presentation();await frames()
    # Chapter two's objectives remain pickable after bounded camera positioning.
    await fresh(preload("res://logic/content.gd").chapter_two_content())
    for pos in [Vector2i(8,1),game.battle.units[0].pos]:
        var seen=false
        for y in [-1,0,1]:
            game.scene_view.pan=game.scene_view.pan_limit*Vector2(0,y);game.scene_view.fit();await frames()
            var point=cell(pos)
            if Rect2(Vector2(0,120),root.get_visible_rect().size-Vector2(0,300)).has_point(point) and not game.hud.pointer_blocks_map(point):
                seen=true;check(game.mouse_cell(point)==pos,"chapter two objective pick at camera boundary")
        check(seen,"chapter two important cell reachable by bounded pan")
    root.size=Vector2i(1080,2400);await frames();check(game.scene_view.pan.abs().x<=game.scene_view.pan_limit.x+0.001 and game.scene_view.pan.abs().y<=game.scene_view.pan_limit.y+0.001,"orientation clamps pan")
    root.size=Vector2i(2400,1080);await frames();check(game.scene_view.art_rect.size==root.get_visible_rect().size,"resize restores cover")
    print("MOBILE_TOUCH_CAMERA checks=",checks," failures=0; synthetic touch, not Android hardware")
    quit()
