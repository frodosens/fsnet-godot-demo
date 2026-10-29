extends "res://tests/test_mobile_touch_camera.gd"
func run():
    app=root.get_node("App");app.sfx_enabled=false;app.mobile_presentation=true;Input.emulate_mouse_from_touch=true
    root.size=Vector2i(1280,800)
    for actor in [0,2]:
        var data=Content.reference_content()
        for y in range(data.height):data.terrain[y]="G".repeat(data.width)
        data.units[0].x=1;data.units[0].y=6;data.units[1].x=2;data.units[1].y=7;data.units[2].x=3;data.units[2].y=6
        data.units[3].x=data.units[actor].x;data.units[3].y=5
        await fresh(data);check(game.select_actor(actor),"choose attacking actor")
        game.select_mode("attack");game.hud.action_menu_open=false;await frames()
        game.update_target_preview(game.battle.units[3].pos);game.hud.refresh();await frames()
        var roster=game.hud.party_selector;var other=1
        check(not game.hud.target_panel.get_global_rect().intersects(roster.get_global_rect()),"target details stay left of roster")
        var point=roster.rows[other].button.get_global_rect().get_center()
        var selected=game.selected;var step=game.battle.step
        # A held roster gesture cannot survive a newly authoritative attack step,
        # including the currently instant Neri basic-action presentation.
        await send_touch(point,true)
        check(app.session.submit({"kind":"attack","unit":actor,"target":3}),"legal actual basic attack")
        game.battle=app.session.logic;game.refresh();game.skip_presentation();await frames()
        await send_touch(point,false)
        check(game.selected==selected and game.battle.step==step+1,"attack completion cannot release a queued actor switch or Wait")
        var truth=game.battle.snapshot()
        for down in [true,false]:
            var mouse=InputEventMouseButton.new();mouse.device=-1;mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=point;mouse.pressed=down;root.push_input(mouse,true);await frames()
        check(game.selected==selected and game.battle.snapshot()==truth,"synthetic mouse duplicate cannot switch or issue Wait")
        await tap(point)
        check(game.selected==other and game.battle.snapshot()==truth,"fresh intentional roster tap after attack still works")
    print("PARTY_ATTACK_HANDOFF checks=",checks," failures=0");quit()
