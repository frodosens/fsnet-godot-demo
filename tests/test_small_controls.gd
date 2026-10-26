extends SceneTree
var failures=0
var checks=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func frames():
    for i in range(4):await process_frame
func key(code):
    for down in [true,false]:
        var e=InputEventKey.new();e.keycode=code;e.pressed=down;root.push_input(e,true);await process_frame
func run():
    var page=Control.new();page.theme=preload("res://ui/style.gd").make_theme();root.add_child(page)
    var box=CheckBox.new();box.text="复选状态";box.position=Vector2(100,100);box.custom_minimum_size=Vector2(220,44);page.add_child(box)
    var slider=HSlider.new();slider.position=Vector2(100,180);slider.size=Vector2(320,44);slider.value=50;page.add_child(slider)
    var scroll=ScrollContainer.new();scroll.position=Vector2(100,250);scroll.size=Vector2(350,180);page.add_child(scroll)
    var list=VBoxContainer.new();scroll.add_child(list)
    for i in range(20):var b=Button.new();b.text="条目 "+str(i);b.custom_minimum_size=Vector2(300,44);list.add_child(b)
    for viewport in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=viewport;await frames();box.button_pressed=false;box.disabled=false;box.grab_focus();await key(KEY_SPACE)
        check(box.button_pressed,"keyboard toggles checkbox")
        box.disabled=true;await key(KEY_SPACE);check(box.button_pressed,"disabled checkbox does not toggle")
        slider.grab_focus();var old=slider.value;await key(KEY_RIGHT);check(slider.value>old,"keyboard changes slider")
        slider.editable=false;old=slider.value;await key(KEY_RIGHT);check(slider.value==old,"disabled slider retains value");slider.editable=true
        var old_scroll=scroll.scroll_vertical
        var wheel=InputEventMouseButton.new();wheel.position=Vector2(200,320);wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;root.push_input(wheel,true);await frames()
        check(scroll.scroll_vertical>old_scroll,"wheel scrolls content with generated scrollbar")
        check(box.size.y>=44 and slider.size.y>=44,"control hit areas separate from small art")
        if DisplayServer.get_name()!="headless":
            await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/small-controls-"+str(viewport.x)+".png")
    print("SMALL_CONTROLS checks=",checks," failures=",failures);quit(1 if failures else 0)
