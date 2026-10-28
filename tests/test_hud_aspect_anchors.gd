extends "res://tests/test_mobile_targeting.gd"
func run():
    app=root.get_node("App");app.mobile_presentation=true;Input.emulate_mouse_from_touch=true
    for physical in [Vector2i(1280,720),Vector2i(1280,800),Vector2i(1024,768),Vector2i(2400,1080),Vector2i(960,600)]:
        root.size=physical;await frames()
        for inset in [false,true]:
            app.safe_area_override=Rect2i(24,12,physical.x-48,physical.y-28) if inset else Rect2i()
            await fresh(fixture());await frames()
            var hud=game.hud;var dock=hud.dock;var safe=app.ui_safe_rect();var scale=dock.canvas.scale.x
            check(is_equal_approx(scale,dock.canvas.scale.y),"uniform UI scale")
            check(absf(dock.canvas.global_position.y+992*scale-safe.end.y)<1,"dock anchored to safe bottom")
            check(absf(dock.phase.get_global_rect().position.y-safe.position.y-dock.r("phase").position.y*scale)<1,"phase remains top anchored")
            for control in [hud.turn_button,dock.confirm,dock.cancel,hud.pause_button]:
                check(safe.grow(1).encloses(control.get_global_rect()),"controls fit safe area")
            for kind in dock.action_nodes:
                check(safe.grow(1).encloses(dock.action_nodes[kind].get_global_rect()),"action fits safe area")
            var before=game.battle.snapshot()
            await button(dock.action_nodes.skill);var picker=hud.modal
            check(is_instance_valid(picker),"touch opens picker")
            check(safe.grow(1).encloses(picker.panel.get_global_rect()),"picker fits safe area")
            check(picker.panel.get_global_rect().end.y<dock.notice.get_global_rect().position.y,"picker clears bottom notice and commands")
            await tap(picker.detail.get_global_rect().get_center())
            check(picker.description_open and safe.grow(1).encloses(picker.description_panel.get_global_rect()),"description fits safe area")
            await tap(picker.description_close.get_global_rect().get_center())
            await tap(safe.position+Vector2(6,6))
            check(not is_instance_valid(hud.modal) and game.battle.snapshot()==before,"outside touch dismisses without map command")
            await button(dock.action_nodes.attack)
            check(game.mode=="attack" and game.battle.snapshot()==before,"direct action remains reachable")
            if OS.get_environment("HUD_CAPTURE_DIR")!="" and not inset:
                await RenderingServer.frame_post_draw
                root.get_texture().get_image().save_png(OS.get_environment("HUD_CAPTURE_DIR")+"/hud-"+str(physical.x)+"x"+str(physical.y)+".png")
    app.safe_area_override=Rect2i()
    print("HUD_ASPECT_ANCHORS checks=",checks," failures=0");quit()
