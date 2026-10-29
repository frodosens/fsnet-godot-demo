extends "res://tests/test_mobile_touch_camera.gd"
func run():
    app=root.get_node("App");app.mobile_presentation=true;Input.emulate_mouse_from_touch=true
    root.size=Vector2i(1200,540);app.safe_area_override=Rect2i(40,24,1136,476);await frames();await fresh()
    await button(game.hud.dock.details_button)
    var page=game.hud.modal
    check(page.tab==0 and not page.list.is_visible_in_tree() and page.description.is_visible_in_tree(),"attributes only expose visible scroller")
    # Attributes now have a real grid. Long trait text exercises the visible nested scroller.
    page.body.text="完整装备特性说明".repeat(200)
    page.body_scroll.scroll_vertical=roundi(page.traits_panel.position.y);await frames()
    var rect=page.description.get_global_rect()
    check(page.body.size.y>page.description.size.y,"long real trait description overflows bounded region")
    var visible=rect.intersection(page.body_scroll.get_global_rect())
    var top=visible.position+Vector2(visible.size.x*.5,visible.size.y*.35)
    var state=game.battle.snapshot();var camera=game.camera.position
    await drag(top,top-Vector2(0,100))
    check(page.description.scroll_vertical>0 and page.list.scroll_vertical==0,"touch scrolls visible traits, not hidden list")
    page.description.scroll_vertical=0;await frames()
    var outer_before_wheel=page.body_scroll.scroll_vertical
    var wheel=InputEventMouseButton.new();wheel.position=root.get_final_transform()*top;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;Input.parse_input_event(wheel);Input.flush_buffered_events();await frames()
    check(page.description.scroll_vertical>0 and page.list.scroll_vertical==0 and page.body_scroll.scroll_vertical==outer_before_wheel,"wheel affects only the visible nested scroller")
    page.description.scroll_vertical=0;await frames()
    var old_outer=page.body_scroll.scroll_vertical
    var key=InputEventKey.new();key.keycode=KEY_UP;key.physical_keycode=KEY_UP;key.pressed=true;root.push_input(key,true);await frames()
    check(page.body_scroll.scroll_vertical<old_outer and page.list.scroll_vertical==0,"keyboard scroll follows visible attributes body")
    page.body_scroll.scroll_vertical=roundi(page.traits_panel.position.y);await frames()
    page.description.scroll_vertical=0;await frames()
    var lower=visible.position+Vector2(visible.size.x*.5,visible.size.y*.85)
    await drag(lower,lower-Vector2(0,100));check(page.description.scroll_vertical>0,"lower drag remains functional")
    check(game.battle.snapshot()==state and game.camera.position==camera,"scroll never leaks into world input")
    await tap(page.full.get_global_rect().get_center());check(page.description_open,"nested details still opens")
    await tap(page.detail_back.get_global_rect().get_center());check(not page.description_open and page.tab==0,"nested close returns to same tab")
    await tap(page.back.get_global_rect().get_center());check(not is_instance_valid(game.hud.modal),"ordinary close remains functional")
    print("DETAILS_VISIBLE_SCROLL checks=",checks," failures=0 actual_small_landscape=true");quit()
