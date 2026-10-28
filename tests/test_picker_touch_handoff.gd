extends "res://tests/test_mobile_targeting.gd"
func run():
    app=root.get_node("App");app.mobile_presentation=true;Input.emulate_mouse_from_touch=true
    for physical in [Vector2i(2400,1080),Vector2i(1280,800)]:
        root.size=physical;await frames();await fresh(fixture())
        await button(game.hud.action_buttons.skill);var picker=game.hud.modal
        var before=game.battle.snapshot();var choice=named("重整").get_global_rect().get_center()
        await send_touch(choice,true,1);await send_touch(choice,false,1)
        check(game.hud.modal==picker,"secondary finger does not select")
        await send_touch(choice,true);await send_touch(choice,false,0,true)
        check(game.hud.modal==picker and game.battle.snapshot()==before,"canceled picker touch does not target or submit")
        await drag(choice,choice-Vector2(0,60))
        check(game.hud.modal==picker,"drag over entry never activates")
        picker.entries[0].description="长说明用于触摸滚动测试，不更改技能规则。".repeat(100)
        await tap(picker.detail.get_global_rect().get_center())
        check(picker.description_open,"raw footer touch opens description")
        var pan=game.scene_view.pan
        var center=picker.description_scroll.get_global_rect().get_center()
        await drag(center,center-Vector2(0,90))
        check(picker.description_scroll.scroll_vertical>0 and game.scene_view.pan==pan and game.battle.snapshot()==before,"raw detail scroll neither pans nor submits")
        await tap(picker.description_close.get_global_rect().get_center())
        check(not picker.description_open and game.hud.modal==picker,"raw close returns to picker")
        await button(named("重整"));check(game.mode=="ability:rally" and not is_instance_valid(game.hud.modal),"raw selection after details closes picker")
        var target=Vector2i(4,7);await tap(cell(target))
        check(game.map_touch==-1 and not game.pending_target.is_empty() and game.battle.snapshot()==before,"first map tap after picker previews and releases finger")
        await tap(cell(target));await tap(cell(target))
        check(game.battle.step==1 and game.session.request_id==1,"second tap commits once, repeat cannot replay")
    print("PICKER_TOUCH_HANDOFF checks=",checks," failures=0 raw_touch_with_emulation=true");quit()
