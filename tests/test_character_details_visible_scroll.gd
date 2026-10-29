extends "res://tests/test_mobile_touch_camera.gd"
func run():
    app=root.get_node("App");app.mobile_presentation=true;Input.emulate_mouse_from_touch=true
    root.size=Vector2i(1200,540);app.safe_area_override=Rect2i(40,24,1136,476);await frames();await fresh()
    await button(game.hud.dock.details_button)
    var page=game.hud.modal
    check(page.tab==0 and not page.list.is_visible_in_tree() and page.description.is_visible_in_tree(),"attributes only expose visible scroller")
    var rect=page.description.get_global_rect();var hidden_rect=page.list.get_global_rect()
    check(page.body.size.y>page.description.size.y,"real attributes overflow small landscape safe area")
    var top=rect.position+Vector2(rect.size.x*.5,rect.size.y*.25)
    check(hidden_rect.has_point(top),"upper drag reproduces hidden-list overlap")
    var state=game.battle.snapshot();var camera=game.camera.position
    await drag(top,top-Vector2(0,100))
    check(page.description.scroll_vertical>0 and page.list.scroll_vertical==0,"upper touch scrolls visible attributes, not hidden list")
    page.description.scroll_vertical=0;await frames()
    var wheel=InputEventMouseButton.new();wheel.position=root.get_final_transform()*top;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;Input.parse_input_event(wheel);Input.flush_buffered_events();await frames()
    check(page.description.scroll_vertical>0 and page.list.scroll_vertical==0,"wheel over overlap ignores hidden scroller")
    page.description.scroll_vertical=0;await frames()
    var key=InputEventKey.new();key.keycode=KEY_DOWN;key.physical_keycode=KEY_DOWN;key.pressed=true;root.push_input(key,true);await frames()
    check(page.description.scroll_vertical>0 and page.list.scroll_vertical==0,"keyboard scroll follows attributes tab")
    page.description.scroll_vertical=0;await frames()
    var lower=rect.position+Vector2(rect.size.x*.5,rect.size.y*.85)
    await drag(lower,lower-Vector2(0,100));check(page.description.scroll_vertical>0,"lower drag remains functional")
    check(game.battle.snapshot()==state and game.camera.position==camera,"scroll never leaks into world input")
    await tap(page.full.get_global_rect().get_center());check(page.description_open,"nested details still opens")
    await tap(page.detail_back.get_global_rect().get_center());check(not page.description_open and page.tab==0,"nested close returns to same tab")
    await tap(page.back.get_global_rect().get_center());check(not is_instance_valid(game.hud.modal),"ordinary close remains functional")
    print("DETAILS_VISIBLE_SCROLL checks=",checks," failures=0 actual_small_landscape=true");quit()
