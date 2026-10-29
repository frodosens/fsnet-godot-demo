extends "res://tests/support/test_case.gd"
var measurements={}
func frames(count=4):
    for i in range(count):await process_frame
func _initialize():call_deferred("run")
func run():
    root.size=Vector2i(1280,800)
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content())
    change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    current_scene.refresh();await frames()
    var hud=current_scene.hud;var view=root.get_visible_rect().size
    var rect=hud.selected_portrait.get_global_rect()
    check(rect.position.distance_to(Vector2(view.x*0.02,view.y*0.80))<0.1,"large portrait normalized top-left")
    check(rect.size.distance_to(Vector2(view.x*0.085,view.y*0.16))<0.1,"large portrait aspect contract")
    var shown=[]
    for child in hud.hero_column.get_children():
        if child is Button and child.visible:shown.append(child)
    check(shown.size()==2,"selected hero is not duplicated in companion row")
    for i in range(shown.size()):
        var actual=shown[i].get_global_rect().get_center();var expected=Vector2(view.x*(0.135+i*0.04),view.y*0.80)
        measurements["companion_"+str(i)]={"actual":[actual.x,actual.y],"target":[expected.x,expected.y],"error_logical_px":actual.distance_to(expected)}
        check(actual.distance_to(expected)<2,"companion portrait normalized center")
    check(not hud.arc_layout.is_empty(),"actor arc has projected layout")
    for kind in ["move","attack","skill","item"]:
        var b=hud.action_buttons[kind]
        check(not hud.ActionArc.visual_rect(b.layout_position).intersects(hud.arc_layout.keepout),"arc avoids selected actor and HP")
    for icon in [hud.hp_icon,hud.mp_icon,hud.action_summary.get_child(0).get_child(1),hud.action_summary.get_child(2).get_child(1)]:
        icon.update_variant()
        var expected_px=20.0*minf(float(root.size.x)/view.x,float(root.size.y)/view.y)
        check(absf(icon.rendered_px-expected_px)<0.1,"icon uses physical viewport scale")
        check(icon.using_small==(expected_px<=20.01),"physical size selects small or large art")
    print("HUD_ICON_PIXELS ",hud.hp_icon.rendered_px," small=",hud.hp_icon.using_small," physical_window=",root.size)
    var snapshot=app.session.logic.snapshot();hud.choose_action("move");current_scene.update_move_preview(Vector2i(4,4));hud.refresh();await frames()
    check(not hud.action_panel.visible and snapshot==app.session.logic.snapshot(),"preview dismisses arc without executing rules")
    hud.cancel_targeting();await frames()
    var move=hud.action_buttons.move
    for i in range(12):move.set_selected(i%2==0)
    move.set_selected(true);await frames(20)
    check(move.selected and move.visual_state=="selected" and move.scale.x<=1.041,"rapid selection settles without accumulating scale")
    check(app.session.submit({"kind":"move","unit":0,"x":4,"y":4}),"move consumes real action budget")
    current_scene.refresh();current_scene.skip_presentation();hud.refresh();await create_timer(0.2).timeout
    check(move.visual_state=="disabled" and move.scale.x<1.01,"disabled state clears selection animation")
    print("HUD_ANCHORS ",JSON.stringify(measurements))
    print("HUD_REFERENCE_LAYOUT checks=",checks," failures=",failures," viewport=",view)
    quit(1 if failures else 0)
