extends "res://tests/test_mobile_targeting.gd"
func click(point):
    var motion=InputEventMouseMotion.new();motion.position=root.get_final_transform()*point
    Input.parse_input_event(motion);Input.flush_buffered_events();await frames()
    for down in [true,false]:
        var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=root.get_final_transform()*point
        Input.parse_input_event(event);Input.flush_buffered_events();await frames()
func gesture(point,touch):
    if touch:await tap(point)
    else:await click(point)
func run():
    app=root.get_node("App");app.mobile_presentation=true;Input.emulate_mouse_from_touch=true
    for physical in [Vector2i(2400,1080),Vector2i(960,600)]:
        root.size=physical;await frames()
        for touch in [true,false]:
            for kind in ["skill","item","attack"]:
                await fresh(fixture())
                game.select_actor(0);await frames(20)
                game.stage_move(Vector2i(3,7));await frames()
                check(not game.pending_move.is_empty(),"move proposal exists")
                var before=game.battle.snapshot();var pan=game.scene_view.pan
                var button_node=game.hud.action_buttons[kind]
                check(button_node.is_visible_in_tree() and not button_node.disabled,"command accessible during Move")
                await gesture(button_node.get_global_rect().get_center(),touch)
                check(game.pending_move.is_empty() and game.preview_path.is_empty() and game.pending_target.is_empty(),"switch clears all proposals")
                check(game.battle.snapshot()==before and game.scene_view.pan==pan,"switch neither submits nor recenters")
                if kind=="attack":
                    check(game.mode=="attack" and Targeting.describe(game).active,"direct Attack range")
                    continue
                var picker=game.hud.modal;check(is_instance_valid(picker),"direct picker opens")
                var outside=game.hud.action_buttons.wait.get_global_rect().get_center()
                picker.entries[0].description="长说明测试".repeat(100)
                await gesture(picker.detail.get_global_rect().get_center(),touch)
                check(picker.description_open,"description opens")
                await gesture(outside,touch)
                check(game.hud.modal==picker and not picker.description_open,"outside details returns only one layer")
                if touch:
                    await drag(picker.scroll.get_global_rect().get_center(),outside)
                    check(game.hud.modal==picker,"inside drag outside does not dismiss")
                if touch:
                    await send_touch(outside,true);await send_touch(outside,false,0,true)
                    check(game.hud.modal==picker,"canceled outside touch does not dismiss")
                await gesture(outside,touch)
                check(not is_instance_valid(game.hud.modal) and game.battle.snapshot()==before,"outside dismiss consumes gesture")
                await gesture(game.hud.action_buttons[kind].get_global_rect().get_center(),touch)
                check(is_instance_valid(game.hud.modal),"picker reopens")
                var entry=named("重整" if kind=="skill" else "药房绷带")
                await gesture(entry.get_global_rect().get_center(),touch)
                await gesture(cell(Vector2i(4,7)),touch)
                check(not game.pending_target.is_empty() and game.battle.snapshot()==before,"first subsequent target previews")
                await gesture(cell(Vector2i(4,7)),touch)
                check(game.battle.step==1 and game.session.request_id==1,"second target commits once")
    print("TARGETING_COMMAND_SWITCH checks=",checks," failures=0");quit()
