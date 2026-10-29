extends "res://tests/test_mobile_touch_camera.gd"
func run():
    app=root.get_node("App");app.mobile_presentation=true;Input.emulate_mouse_from_touch=true
    for physical in [Vector2i(2400,1080),Vector2i(1280,800),Vector2i(1600,1200)]:
        root.size=physical;app.safe_area_override=Rect2i(40,16,physical.x-64,physical.y-32);await frames();await fresh()
        var before=game.battle.snapshot();var position=game.camera.position
        await button(game.hud.dock.portrait_button)
        var page=game.hud.modal;check(is_instance_valid(page),"raw portrait touch opens with emulation")
        check(app.ui_safe_rect().encloses(page.panel.get_global_rect()),"details safe area")
        await tap(page.tabs[3].get_global_rect().get_center());check(page.tab==3,"equipment tab raw touch")
        await drag(page.list.get_global_rect().get_center(),page.list.get_global_rect().get_center()-Vector2(0,110))
        check(page.selected_uid==-1 and page.list.scroll_vertical>0,"inventory scroll does not select or equip")
        var offset=page.list.scroll_vertical
        await tap(page.full.get_global_rect().get_center());check(page.description_open,"raw fulltext opens")
        await tap(page.detail_back.get_global_rect().get_center());check(not page.description_open and page.list.scroll_vertical==offset,"fulltext retains list scroll")
        check(game.camera.position.is_equal_approx(position) and game.battle.snapshot()==before,"modal gestures cannot move camera or command")
        await tap(page.get_global_rect().position+Vector2(2,2));check(not is_instance_valid(game.hud.modal),"outside gesture closes only modal")
        game.select_mode("move");await frames()
        var reachable=game.battle.reachable(game.selected);var destination=game.battle.units[game.selected].pos
        for pos in reachable:
            if pos!=destination and game.battle.at(pos)<0:destination=pos;break
        game.scene_view.pan=Vector2.ZERO;game.scene_view.fit();await frames()
        await tap(cell(destination));check(not game.pending_move.is_empty() and game.battle.snapshot()==before,"first post-close map touch not swallowed")
        game.clear_move_preview();await button(game.hud.dock.details_button);page=game.hud.modal
        await send_touch(page.back.get_global_rect().get_center(),true)
        await send_touch(page.back.get_global_rect().get_center(),false,0,true)
        check(is_instance_valid(game.hud.modal),"cancelled close does not dismiss")
        await send_touch(page.back.get_global_rect().get_center(),true)
        await send_touch(page.back.get_global_rect().get_center(),true,1)
        await send_touch(page.back.get_global_rect().get_center(),false,1)
        await send_touch(page.back.get_global_rect().get_center(),false)
        check(is_instance_valid(game.hud.modal),"multifinger cannot activate close")
        game.hud.clear_modal();await frames()
    print("CHARACTER_DETAILS_TOUCH checks=",checks," failures=0");quit()
