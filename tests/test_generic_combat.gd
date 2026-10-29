extends "res://tests/test_attack_feedback.gd"
var generic_id=""
var generic_target=false
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL: ",label);quit(1)
    assert(ok,label)
func fresh(actor=0,hp=6,armor=0):
    var d=load('res://logic/content.gd').reference_content();d.story.events=[]
    d.units[0].x=4;d.units[0].y=7;d.units[1].x=2;d.units[1].y=8;d.units[2].x=3;d.units[2].y=8
    d.units[3].x=5;d.units[3].y=7;d.units[3].hp=hp;d.units[3].armor=armor
    d.units[3 if generic_target else 0].id=generic_id;d.units[3 if generic_target else 0].name="通用单位测试"
    check(load('res://logic/content.gd').validate(d).is_empty(),'legal unchanged-rule fixture')
    app.new_game(d);change_scene_to_file('res://main.tscn');await frames(6);g=current_scene
    g.select_actor(0);g.scene_view.cancel_focus();g.selection_pending_focus=false;g.select_mode('attack');await frames()
func run():
    app=root.get_node('App');app.mobile_presentation=true
    for id in preload('res://view/map_sequence.gd').CATALOG_IDS:
        generic_id=id
        for defender in [false,true]:
            generic_target=defender;await fresh(0,1)
            var before=g.battle.snapshot()
            await touch(Vector2i(5,7));check(not g.pending_target.is_empty() and g.battle.snapshot()==before,'actual target preview')
            await touch(Vector2i(5,7))
            check(g.battle.step==1 and g.battle.units[3].hp==0,'actual lethal command')
            check(g.generic_attack_feedback.active() and not g.cutin.active,'map feedback, no borrowed hero cutin')
            check(g.generic_attack_feedback.label.visible and g.generic_attack_feedback.event.damage>0,'visible authoritative damage')
            check(g.figures[3].visible and g.presentation_active(),'lethal sprite retained during feedback')
            check(not g.select_actor(1) and not g.wait_selected(),'busy blocks switch and wait')
            var truth=g.battle.snapshot();var event=g.generic_attack_feedback.event.duplicate(true)
            await touch(Vector2i(5,7));check(g.battle.snapshot()==truth,'duplicate touch no second action')
            g.refresh();check(g.generic_attack_feedback.event==event,'duplicate refresh no replay')
            var capture=OS.get_environment('GENERIC_COMBAT_CAPTURE')
            if not capture.is_empty() and defender:
                await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(capture+'/'+id+'.png')
            await settle();check(not g.generic_attack_feedback.active() and not g.figures[3].visible,'death settles after visible damage')
            check(g.selected==0 and g.battle.snapshot()==truth,'no auto-next or rule mutation')
    generic_id='generic_bandit_01';generic_target=true;await fresh();await touch(Vector2i(5,7));await touch(Vector2i(5,7))
    var truth=g.battle.snapshot();g.skip_presentation();check(not g.generic_attack_feedback.active() and g.battle.snapshot()==truth,'skip clears feedback without replay')
    print('GENERIC_COMBAT checks=',checks,' failures=0 actual_touch=true');quit()
