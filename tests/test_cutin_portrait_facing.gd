extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func frames():
    for i in range(3):await process_frame
func run():
    var data=preload("res://logic/content.gd").reference_content()
    data.units[3].x=data.units[0].x+1;data.units[3].y=data.units[0].y
    var logic=preload("res://logic/runtime.gd").new(data)
    check(logic.apply_command({"kind":"attack","unit":0,"target":3,"step":1}),"real Lua attack")
    var truth=logic.snapshot()
    var cutin=load("res://ui/battle_cutin.gd").new();root.add_child(cutin);cutin.set_process(false)
    cutin.consume(logic.step,logic.events,logic.units,logic.content)
    var status=cutin.combat_status
    var event=cutin.event.duplicate(true)
    for pass_index in range(2):
        for pair in [["mara","oren"],["oren","mara"],["finn","neri"],["bram","tessa"],["adela","elsbet"],["elsbet","adela"],["unknown_mod","unknown_target"]]:
            var sample=event.duplicate(true);sample.actor=pair[0];sample.target=pair[1]
            sample.actor_profile=preload("res://logic/presentation_profiles.gd").resolve({"id":pair[0]});sample.target_profile=preload("res://logic/presentation_profiles.gd").resolve({"id":pair[1]})
            status.show_event(sample)
            check(not status.portraits.left.flip_h and status.portraits.right.flip_h,"screen side independent of ID and reuse")
            for side in ["left","right"]:
                var id=pair[0] if side=="left" else pair[1]
                var path=preload("res://view/reserve_art.gd").portrait_path(id)
                check(status.portraits[side].texture==(load(path) if ResourceLoader.exists(path) else null),"original resource or missing fallback")
                check(status.portraits[side].scale==Vector2.ONE and not status.portraits[side].flip_v,"no transform or vertical flip")
                check(status.labels[side].scale==Vector2.ONE and status.bars[side].scale==Vector2.ONE,"text and HP unmirrored")
    status.show_event(event)
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;cutin.layout_surface();await frames()
        for pair in [["oren","mara"],["adela","elsbet"],["elsbet","adela"]]:
            var sample=event.duplicate(true);sample.actor=pair[0];sample.target=pair[1]
            sample.actor_profile=preload("res://logic/presentation_profiles.gd").resolve({"id":pair[0]});sample.target_profile=preload("res://logic/presentation_profiles.gd").resolve({"id":pair[1]})
            cutin.pending_events=[sample];cutin.play_next();cutin.draw_tick(0);await frames()
            check(status.portraits.right.flip_h and not status.portraits.left.flip_h,"rendered reverse/reserve roles retain side facing")
        cutin.pending_events=[event.duplicate(true)];cutin.play_next();cutin.draw_tick(0);await frames()
        check(status.portraits.right.flip_h and not status.portraits.left.flip_h,"draw tick preserves facing")
        var output=OS.get_environment("AMBER_PORTRAIT_CAPTURE")
        if not output.is_empty():
            # The sole old behavior is right flip_h=false; same frozen real event.
            status.portraits.right.flip_h=false;await frames();await RenderingServer.frame_post_draw
            var before=root.get_texture().get_image()
            status.show_event(event);await frames();await RenderingServer.frame_post_draw
            var after=root.get_texture().get_image()
            var area=status.portraits.right.get_global_rect()
            var ratio=Vector2(after.get_size())/root.get_visible_rect().size
            area=Rect2(area.position*ratio,area.size*ratio).grow(2)
            var changed=0;var outside=0
            for y in range(after.get_height()):
                for x in range(after.get_width()):
                    if before.get_pixel(x,y)!=after.get_pixel(x,y):
                        changed+=1
                        if not area.has_point(Vector2(x,y)):outside+=1
            check(changed>100,"actual portrait pixels mirrored")
            check(outside==0,"all pixels outside right portrait unchanged")
            before.save_png(output+"/before-"+str(size.x)+".png")
            after.save_png(output+"/after-"+str(size.x)+".png")
    cutin.finish();cutin.consume(99,logic.events,logic.units,logic.content)
    check(status.portraits.right.flip_h and not status.portraits.left.flip_h,"scene reuse after finish")
    check(logic.snapshot()==truth,"presentation preserves authoritative state")
    cutin.finish();cutin.queue_free();await frames()
    print("CUTIN_PORTRAIT_FACING checks=",checks," failures=",failures);quit(1 if failures else 0)
