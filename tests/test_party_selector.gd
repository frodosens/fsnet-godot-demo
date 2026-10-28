extends "res://tests/test_mobile_touch_camera.gd"
func run():
    app=root.get_node("App");app.mobile_presentation=true;Input.emulate_mouse_from_touch=true
    await fresh()
    check(game.hud.party_selector.size.x<=game.hud.root.size.x*.15,"default viewport cannot inflate roster hit region")
    for physical in [Vector2i(1280,800),Vector2i(1920,1080),Vector2i(1600,1200),Vector2i(2400,1080)]:
        root.size=physical;app.safe_area_override=Rect2i(24,12,physical.x-48,physical.y-24);await frames();await fresh()
        var roster=game.hud.party_selector;var truth=game.battle.snapshot()
        check(roster.rows.size()==3,"only three existing allied playable members")
        check(roster.size.y<=roster.rows.size()*65,"short roster has no invisible map-blocking tail")
        check(app.ui_safe_rect().encloses(roster.get_global_rect()),"safe area contains roster")
        check(roster.position.x>game.hud.root.size.x*.8,"right side compact placement")
        for i in roster.rows:
            check(roster.rows[i].button.size.y>=48,"accessible hit height")
            check(roster.rows[i].eye.texture is AtlasTexture,"original portrait crop")
            check(roster.rows[i].button.find_children("*","ProgressBar",true,false).is_empty(),"no roster HP")
        await tap(roster.rows[1].button.get_global_rect().get_center())
        check(game.selected==1 and game.mode=="move","raw touch directly selects and enters Move")
        check(game.battle.snapshot()==truth and game.pending_move.is_empty(),"selection no command or stale preview")
        await create_timer(.4).timeout;await frames()
        var pos=game.camera.position
        await drag(roster.rows[0].button.get_global_rect().get_center(),Vector2(400,300))
        check(game.selected==1 and game.camera.position.is_equal_approx(pos),"roster-origin drag cannot select or pan world")
        var point=roster.rows[0].button.get_global_rect().get_center()
        await send_touch(point,true);await send_touch(point,false,0,true)
        check(game.selected==1,"canceled gesture cannot select")
        await send_touch(point,true,1);await send_touch(point,false,1)
        check(game.selected==1,"secondary finger never selects roster")
        await tap(point);check(game.selected==0,"next roster gesture not lost")
        game.scene_view.cancel_focus();game.selection_pending_focus=false
        var destination=Vector2i(2,8)
        await tap(cell(destination));check(not game.pending_move.is_empty(),"first subsequent map tap previews")
        game.clear_move_preview()
        check(app.session.submit({"kind":"move","unit":0,"x":2,"y":8}),"legal move")
        game.battle=app.session.logic;game.refresh();await frames()
        check(roster.rows[0].eye.material.get_shader_parameter("faded")==1.0,"moved eye desaturated")
        var selected=game.selected;await tap(roster.rows[1].button.get_global_rect().get_center())
        check(game.selected==selected,"execution lock rejects switch")
        var busy_point=roster.rows[1].button.get_global_rect().get_center()
        await send_touch(busy_point,true)
        game.skip_presentation();await frames()
        await send_touch(busy_point,false)
        check(game.selected==selected,"gesture begun during execution cannot queue a post-completion switch")
        await tap(roster.rows[1].button.get_global_rect().get_center());await tap(roster.rows[0].button.get_global_rect().get_center())
        check(game.selected==0 and not game.battle.units[0].acted,"moved member still selectable with action remaining")
        check(game.active_actor_marker.actor_index==0 and game.active_actor_marker.arrow.mouse_filter==Control.MOUSE_FILTER_IGNORE,"single decorative selected arrow")
        app.reduced_motion=true;await frames();var phase=game.active_actor_marker.clock;await frames()
        check(game.active_actor_marker.clock==phase,"reduced motion freezes pulse and bob")
        app.reduced_motion=false
        var capture=OS.get_environment("PARTY_UI_CAPTURE")
        if not capture.is_empty():
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png(capture+"/party-"+str(physical.x)+".png")
        # Native focus/keyboard and mouse share the same guarded selection callback.
        await create_timer(.55).timeout
        var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=roster.rows[1].button.get_global_rect().get_center();click.pressed=true;root.push_input(click,true);await frames()
        click=click.duplicate();click.pressed=false;root.push_input(click,true);await frames()
        check(game.selected==1,"mouse roster selection")
        roster.rows[0].button.grab_focus()
        var key=InputEventKey.new();key.keycode=KEY_SPACE;key.physical_keycode=KEY_SPACE;key.pressed=true;root.push_input(key,true);await frames()
        key=key.duplicate();key.pressed=false;root.push_input(key,true);await frames()
        check(game.selected==0,"keyboard focused roster selection")
        roster.rows[1].button.grab_focus()
        var joy=InputEventJoypadButton.new();joy.button_index=JOY_BUTTON_A;joy.pressed=true;root.push_input(joy,true);await frames()
        joy=joy.duplicate();joy.pressed=false;root.push_input(joy,true);await frames()
        check(game.selected==1,"controller focused roster selection")
        check(app.session.submit({"kind":"wait","unit":0}),"legal completed-member fixture")
        game.battle=app.session.logic;game.refresh();await frames()
        check(roster.rows[0].state.get_meta("status")=="done","fully done has separate check indicator")
        # Bounded presentation fixture for long Mod rosters, not production content.
        game.set_process(false);game.get_node("MapIdle").set_process(false)
        for i in range(16):
            var unit=game.battle.units[0].duplicate(true);unit.id="test_extra_"+str(i);game.battle.units.append(unit)
        roster.refresh();await frames()
        check(roster.rows.size()==19 and roster.scroll.get_v_scroll_bar().max_value>roster.scroll.size.y,"large roster scrolls")
        var original=roster.scroll.scroll_vertical
        await drag(roster.get_global_rect().get_center()+Vector2(0,80),roster.get_global_rect().get_center()-Vector2(0,80))
        check(roster.scroll.scroll_vertical>original,"touch scroll does not select")
    print("PARTY_SELECTOR checks=",checks," failures=0");quit()
