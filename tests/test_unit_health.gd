extends SceneTree
var checks=0
var failures=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func frames():
    for i in range(4):await process_frame
func run():
    root.size=Vector2i(1280,800)
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();var truth=game.battle.snapshot();var measurements=[]
    for size in [Vector2i(960,600),Vector2i(1280,800),Vector2i(1920,1080)]:
        root.size=size;await frames()
        for fixed in [false,true]:
            check(game.scene_view.set_fixed(fixed),"renderer switch")
            await frames()
            var camera=game.camera;var scale=Vector2(root.size)/root.get_visible_rect().size
            for i in range(game.badges.size()):
                var bar=game.badges[i];var frame=bar.frame
                var a=camera.unproject_position(bar.position-camera.global_basis.y*12*frame.pixel_size*frame.scale.y)*scale
                var b=camera.unproject_position(bar.position+camera.global_basis.y*12*frame.pixel_size*frame.scale.y)*scale
                check(a.distance_to(b)>=7.9,"meter physical height >=8px")
                check(bar.marker.text==("◆" if game.battle.units[i].ally else "▲"),"faction distinguished by shape")
                var image=game.figures[i].texture.get_image();var top=128
                for y in range(image.get_height()):
                    for x in range(image.get_width()):
                        if image.get_pixel(x,y).a>=0.5:top=y;break
                    if top<128:break
                var head=camera.unproject_position(game.figures[i].position+Vector3.UP*(64-top)*game.figures[i].pixel_size)*scale
                var center=camera.unproject_position(bar.position)*scale
                check(head.y-center.y-bar.rendered_size.y*0.5>1.0,"meter clears opaque head by at least one physical pixel")
                measurements.append({"viewport":[size.x,size.y],"fixed":fixed,"id":game.battle.units[i].id,"height_px":a.distance_to(b)})
    var bar=game.badges[0];bar.update_health(5,10,true);check(bar.fill.region_rect.size.x==156,"half HP from real ratio")
    check(bar.damage_time>0,"damage briefly emphasizes meter")
    bar._process(1.0);check(bar.damage_time==0,"damage emphasis settles")
    bar.update_health(0,10,true);check(not bar.visible and not bar.fill.visible,"dead meter hidden")
    bar.update_health(10,10,true);check(bar.visible and bar.fill.region_rect.size.x==312,"full-health meter retained")
    check(game.battle.snapshot()==truth,"presentation does not mutate rules")
    var file=FileAccess.open("res://docs/unit-health-pixel-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(measurements,"  "))
    print("UNIT_HEALTH checks=",checks," failures=",failures," physical_minimum=8px")
    quit(1 if failures else 0)
