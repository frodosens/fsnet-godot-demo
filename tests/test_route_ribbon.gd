extends SceneTree
var checks=0
var failures=0
func check(value):
    checks+=1
    if not value:failures+=1;printerr("FAIL: ribbon check ",checks)
func _initialize():call_deferred("run")
func frames():
    for i in range(3):await process_frame
func run():
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.hud.choose_action("move");var ribbon=game.ground_overlay;var truth=game.battle.snapshot()
    for sample in range(321):
        var time=sample*0.01
        var inner=ribbon.range_alpha(1,4,time,false);var outer=ribbon.range_alpha(4,4,time,false)
        check(inner.x>outer.x and inner.y>outer.y);check(outer.x>=0.50 and outer.y>=0.29)
        var previous=1.0
        for cost in range(5):
            var fill=ribbon.range_alpha(cost,4,time,false).x
            check(fill>=0.50 and fill<=previous);previous=fill
        check(ribbon.range_alpha(4,4,time,true)==ribbon.range_alpha(4,4,0,true))
    for path in [[],[{"x":4,"y":7}],[{"x":4,"y":7},{"x":4,"y":6}],[{"x":4,"y":7},{"x":4,"y":6},{"x":5,"y":6},{"x":5,"y":5}],[{"x":4,"y":7},{"x":4,"y":6},{"x":4,"y":7}]]:
        var points=ribbon.rounded_route(path)
        if path.size()<2:check(points.is_empty());continue
        check(points[0]==Vector2(path[0].x,path[0].y));check(points[-1]==Vector2(path[-1].x,path[-1].y))
        for point in points:
            var legal=false
            for cell in path:
                if absf(point.x-cell.x)<=0.5 and absf(point.y-cell.y)<=0.5:legal=true
            check(legal) # Rounded corners remain within the union of authorised path cells.
    game.update_move_preview(Vector2i(4,4));ribbon._process(0.01);check(ribbon.reveal<ribbon.route_length)
    ribbon._process(1.0);check(is_equal_approx(ribbon.reveal,ribbon.route_length))
    for target in [Vector2i(3,7),Vector2i(4,5),Vector2i(5,7)]:game.update_move_preview(target);ribbon._process(0.01)
    game.clear_move_preview();ribbon._process(0.01);check(ribbon.last_path.is_empty() and ribbon.reveal==0)
    app.reduced_motion=true;game.update_move_preview(Vector2i(4,4));ribbon._process(0);check(is_equal_approx(ribbon.reveal,ribbon.route_length))
    game.update_move_preview(Vector2i(0,4));ribbon._process(0.01);check(ribbon.last_path.is_empty())
    check(game.battle.snapshot()==truth)
    print("ROUTE_RIBBON checks=",checks," failures=",failures," bounded_corners=true cancel_reset=true rng_unchanged=true")
    quit(1 if failures else 0)
