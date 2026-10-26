extends SceneTree
var checks=0
var failures=0
var measurements={}
func check(value,label):
    checks+=1
    if not value:failures+=1;printerr("FAIL: ",label)
func frames(count=4):
    for i in range(count):await process_frame
func _initialize():call_deferred("run")
func run():
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
    for i in range(4):
        var kind=["move","attack","skill","item"][i];var button=hud.action_buttons[kind]
        var center=button.get_global_transform()*Vector2(32,32);var target=Vector2(view.x*0.88,view.y*[0.31,0.41,0.50,0.59][i])
        measurements[kind]={"actual":[center.x,center.y],"target":[target.x,target.y],"error_logical_px":center.distance_to(target)}
        check(center.distance_to(target)<0.1,"action anchor "+kind)
    var snapshot=app.session.logic.snapshot();current_scene.update_move_preview(Vector2i(4,4));hud.refresh();await frames()
    check(hud.action_panel.visible and snapshot==app.session.logic.snapshot(),"preview keeps action menu and does not execute rules")
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
