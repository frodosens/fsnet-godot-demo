extends SceneTree
var failures=0
var checks=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func frames():
    for i in range(8):await process_frame
func run():
    var app=root.get_node("App");app.mobile_presentation=true;app.new_game()
    var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
    await frames();game.hud.advance(true);await frames()
    for physical in [Vector2i(1280,800),Vector2i(1280,720),Vector2i(1600,720),Vector2i(960,540),Vector2i(1200,540)]:
        root.size=physical;app.safe_area_override=Rect2i(40,24,physical.x-64,physical.y-64) if physical.x==1200 else Rect2i();await frames()
        game.hud.show_character_details();await frames();var page=game.hud.modal
        var bounds=page.panel.get_global_rect();var ratio=page.ui_ratio()
        check(app.ui_safe_rect().encloses(bounds),"panel inside safe area "+str(physical))
        check(absf(page.portrait.size.x/page.portrait.size.y-323.0/406.0)<.001,"portrait ratio invariant "+str(physical))
        for node in page.tabs+[page.close_button,page.back,page.full]:
            check(bounds.grow(.1).encloses(node.get_global_rect()),"fixed navigation stays inside panel")
            check(node.size.y*ratio>=44-.1,"physical touch height >=44")
        var nav_bottom=page.tabs[0].get_global_rect().end.y
        check(page.body_scroll.get_global_rect().position.y>=nav_bottom,"body below tabs")
        check(page.body_scroll.get_global_rect().end.y<=page.back.get_global_rect().position.y+.1,"body excludes footer")
        check(not page.xp_group.get_global_rect().intersects(page.level_label.get_global_rect()),"XP separate from level")
        check(page.summary.get_global_rect().end.y<=page.identity_panel.get_global_rect().end.y-12/ratio,"XP text clears identity bottom border by 12 physical pixels")
        check(not page.xp_group.get_global_rect().intersects(page.summary.get_global_rect()),"XP fill and text have distinct rows")
        check(page.stat_rows.size()==10,"ten cells")
        check(page.stat_rows[0].value.text=="12 / 12" and page.stat_rows[2].value.text=="0 / 0","current/max data combined without loss")
        for i in range(0,10,2):
            check(page.stat_rows[i].root.get_global_rect().end.x<=page.stat_rows[i+1].root.get_global_rect().position.x,"two nonoverlapping columns")
        if not page.compact:
            var scale=minf(page.size.x/1672,page.size.y/941)
            check(page.attributes_panel.size.distance_to(Vector2(738,376)*scale)<.1,"measured attributes dimensions")
            check(page.traits_panel.size.distance_to(Vector2(738,151)*scale)<.1,"measured traits dimensions")
        if physical.x==960:check(page.equipment_panel.get_parent()==page.body_canvas,"narrow summary follows traits")
        page.identity.text="极长角色名称测试".repeat(8);page.class_label.text="很长的职业名称".repeat(8);await frames()
        check(page.identity.size.x<=page.identity_panel.size.x,"long localized identity bounded")
        game.hud.clear_modal();await frames()
    print("DETAILS_LAYOUT checks=",checks," failures=",failures);quit(1 if failures else 0)
