extends "res://tests/test_mobile_touch_camera.gd"
func visible_center(node,page):
    return node.get_global_rect().intersection(page.list.get_global_rect()).intersection(page.body_scroll.get_global_rect()).get_center()
func run():
    app=root.get_node("App");app.mobile_presentation=true;Input.emulate_mouse_from_touch=true
    root.size=Vector2i(960,540);await frames();await fresh()
    await button(game.hud.dock.details_button);var page=game.hud.modal
    check(page.compact and page.equipment_panel.get_parent()==page.body_canvas,"narrow layout stacks current equipment")
    var before=game.battle.snapshot();var camera=game.camera.position
    # Non-overflowing traits must not swallow the drag intended for the outer content.
    page.body_scroll.scroll_vertical=260;await frames()
    var point=page.description.get_global_rect().intersection(page.body_scroll.get_global_rect()).get_center()
    var previous=page.body_scroll.scroll_vertical
    await drag(point,point-Vector2(0,70))
    check(page.body_scroll.scroll_vertical>previous,"short trait drag falls through to outer scroll")
    check(game.battle.snapshot()==before and game.camera.position==camera,"body scroll cannot reach world")
    page.body_scroll.scroll_vertical=0;await frames();await button(page.tabs[3])
    page.list.ensure_control_visible(page.rows[5]);await frames()
    await tap(visible_center(page.rows[5],page));check(page.slot==5,"real touch selects feet after scrolling")
    var item
    for row in page.rows:
        if row.get_meta("key")=="item2":item=row
    check(is_instance_valid(item),"compatible equipment remains in shared inventory")
    page.list.ensure_control_visible(item);await frames()
    await tap(visible_center(item,page));check(page.selected_uid==2 and not page.equip.disabled,"real touch selects authoritative preview")
    check(game.battle.snapshot()==before,"preview remains isolated")
    var step=game.battle.step;await button(page.equip)
    check(game.battle.step==step+1 and game.battle.units[0].move_actions==2,"footer touch equips once after nested scrolling")
    await button(page.close_button);check(not is_instance_valid(game.hud.modal),"new close control respects real touch")
    print("DETAILS_NESTED_TOUCH checks=",checks," failures=0");quit()
