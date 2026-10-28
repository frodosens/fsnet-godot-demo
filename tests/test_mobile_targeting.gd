extends "res://tests/test_mobile_touch_camera.gd"
const Targeting=preload("res://view/targeting_preview.gd")
func fixture():
    var data=preload("res://logic/content.gd").reference_content()
    data.units[3].x=5;data.units[3].y=7;data.units[5].x=4;data.units[5].y=6
    return data
func named(prefix):
    for b in game.find_children("*","Button",true,false):
        if b.is_visible_in_tree() and not b.disabled and b.text.begins_with(prefix):return b
    return null
func run():
    app=root.get_node("App");app.mobile_presentation=true;Input.emulate_mouse_from_touch=true
    for physical in [Vector2i(2400,1080),Vector2i(1280,800)]:
        root.size=physical;await frames()
        for mode in ["attack","ability:rally","item:bandage"]:
            await fresh(fixture())
            if mode=="attack":await button(game.hud.action_buttons.attack)
            elif mode.begins_with("ability"):
                await button(game.hud.action_buttons.skill);await button(named("重整"))
            else:
                await button(game.hud.action_buttons.item);await button(named("药房绷带"))
            check(game.pending_target.is_empty() and game.battle.step==0,"menu touch never commits")
            var before=game.battle.snapshot();var target=Vector2i(5,7) if mode=="attack" else Vector2i(4,7)
            var preview=Targeting.describe(game)
            check(preview.active and preview.legal_cells.has(target),"legal target highlighted "+mode)
            for i in range(game.battle.units.size()):
                check(preview.legal_cells.has(game.battle.units[i].pos)==game.battle.preview_action(game.target_command(i)).get("legal",false),"gold cells match Lua authority")
            game.scene_view.pan_by(Vector2(0,-30));await frames()
            check(game.mouse_cell(cell(target))==target,"target projection after pan/zoom")
            await tap(cell(target));await frames()
            check(not game.pending_target.is_empty() and game.battle.snapshot()==before,"raw first touch previews without costs "+mode)
            preview=Targeting.describe(game)
            check(preview.hover_legal and target in preview.area_cells,"effect footprint follows selected target")
            await tap(cell(target));await tap(cell(target))
            check(game.battle.step==1 and game.session.request_id==1,"raw second touch with emulation commits exactly once "+mode)
        await fresh(fixture());game.selected=2;game.select_mode("ability:ember");await frames()
        var before=game.battle.snapshot();var preview=Targeting.describe(game)
        check(preview.active and preview.cast_cells.size()>1,"skill cast reach visible before target")
        game.update_target_preview(Vector2i(5,7));await frames();preview=Targeting.describe(game)
        check(preview.hover_legal and preview.area_cells.size()>1,"AoE differs from cast reach")
        check("oren" in preview.affected_units and not "neri" in preview.affected_units,"AoE recipients respect faction")
        check(game.battle.snapshot()==before,"range queries do not mutate authoritative state")
        game.update_target_preview(Vector2i(4,7));await frames();preview=Targeting.describe(game)
        check(not preview.hover_legal and preview.area_cells.is_empty() and not preview.reason.is_empty(),"invalid faction has cue and no stale effect area")
        game.select_mode("move");await frames();check(not Targeting.describe(game).active,"mode switch clears range")
        game.selected=2;game.select_mode("ability:ember");await frames()
        await tap(cell(Vector2i(5,7)));check(not game.pending_target.is_empty(),"skill staged")
        var center=root.get_visible_rect().size*Vector2(0.55,0.4)
        await drag(center,center+Vector2(50,50))
        check(game.pending_target.is_empty() and game.battle.snapshot()==before,"drag clears proposal and cannot cast")
        await tap(cell(Vector2i(5,7)));check(game.battle.step==0,"first tap after drag only stages")
        game.session.pending=true;game.session.command_pending=true;await frames()
        check(not Targeting.describe(game).active,"network pending hides stale targets")
        await tap(cell(Vector2i(5,7)));check(game.battle.step==0,"pending request prevents duplicate submit")
        game.session.pending=false;game.session.command_pending=false
    var no_mana=fixture();no_mana.units[2].mp=0
    await fresh(no_mana);game.selected=2;game.select_mode("ability:focus_bolt");await frames()
    var unavailable=Targeting.describe(game)
    check(unavailable.legal_cells.is_empty() and unavailable.reason=="法力不足","insufficient resources shown without legal targets")
    await fresh(fixture());game.selected=2;game.select_mode("ability:ember");await frames()
    await tap(cell(Vector2i(5,7)));game.select_mode("ability:focus_bolt");await frames()
    check(game.pending_target.is_empty() and Targeting.describe(game).area_cells.is_empty(),"skill switch clears previous effect area")
    game.hud.cancel_targeting();await frames();check(not Targeting.describe(game).active,"cancel clears targeting overlay")
    await fresh(fixture());check(not Targeting.describe(game).active,"new scene/load starts without stale overlay")
    print("MOBILE_TARGETING checks=",checks," failures=0 synthetic_raw_touch=true");quit()
