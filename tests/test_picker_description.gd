extends "res://tests/support/test_case.gd"
const Picker=preload("res://ui/content_picker.gd")
var activations=0
func _initialize():call_deferred("run")
func frames():
    for i in range(5):await process_frame
func key(code):
    var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;root.push_input(e,true)
func click(point):
    for down in [true,false]:
        var e=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true)
func joy(button):
    var e=InputEventJoypadButton.new();e.button_index=button;e.pressed=true;root.push_input(e,true)
func run():
    var host=Control.new();host.theme=Style.make_theme();host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(host)
    var body="法术命中目标后造成伤害并降低护盾。目标必须处于有效射程内，不能穿越墙壁。冷却结束后才能再次施放。".repeat(30)+"\n"+"ModDescriptionWithoutAnySpaces".repeat(30)+"\n末尾说明可读。"
    root.min_size=Vector2i(320,240)
    for viewport in [Vector2i(1280,800),Vector2i(960,600),Vector2i(960,540)]:
        root.size=viewport;await frames()
        var picker=Picker.new();picker.title="长说明测试"
        for i in range(37):picker.entries.append({"id":"fixture_"+str(i),"name":"测试技能"+str(i),"summary":"MP 2 · 冷却 0","description":body,"reason":"法力不足" if i==1 else ""})
        picker.activated.connect(func(_id):activations+=1);host.add_child(picker);await frames()
        picker.navigate(20);await frames();var selected=picker.selected_index;var grid_scroll=picker.scroll.scroll_vertical
        click(picker.detail.get_global_rect().get_center());await frames()
        check(picker.description_open and picker.description_text.text.ends_with("末尾说明可读。"),"click exposes full plain text")
        check(picker.description_text.autowrap_mode==TextServer.AUTOWRAP_WORD_SMART and picker.description_text.get_line_count()>20,"Chinese and no-space Mod text wrap")
        check(picker.description_scroll.get_h_scroll_bar().visible==false,"no horizontal overflow")
        check(picker.description_text.size.x<=picker.description_scroll.size.x,"wrapped text inside width")
        var point=picker.description_scroll.get_global_rect().get_center()
        var touch=InputEventScreenTouch.new();touch.position=point;touch.pressed=true;root.push_input(touch,true)
        var drag=InputEventScreenDrag.new();drag.position=point-Vector2(0,90);root.push_input(drag,true)
        touch=InputEventScreenTouch.new();touch.position=point-Vector2(0,90);touch.pressed=false;root.push_input(touch,true);await frames()
        check(picker.description_scroll.scroll_vertical>0 and activations==0,"detail touch scroll never activates skill")
        var before=picker.description_scroll.scroll_vertical
        var wheel=InputEventMouseButton.new();wheel.position=point;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;root.push_input(wheel,true);await frames()
        check(picker.description_scroll.scroll_vertical>before,"detail wheel scroll")
        key(KEY_DOWN);await frames();check(picker.description_scroll.scroll_vertical>before,"keyboard scrolls description")
        picker.description_scroll.scroll_vertical=100000;await frames()
        check(picker.description_scroll.scroll_vertical>picker.description_scroll.size.y,"full description end reachable")
        key(KEY_ESCAPE);await frames()
        check(not picker.description_open and not picker.closing and picker.selected_index==selected and picker.scroll.scroll_vertical==grid_scroll,"Escape restores selection and exact grid offset")
        check(picker.detail.has_focus(),"return restores detail focus")
        key(KEY_ENTER);await frames();check(picker.description_open,"keyboard focused footer opens description")
        joy(JOY_BUTTON_B);await frames();check(not picker.description_open,"controller B returns only to list")
        picker.select(1);picker.cells[1].grab_focus();joy(JOY_BUTTON_Y);await frames()
        check(picker.description_open and picker.description_text.text.contains("法力不足"),"controller reads disabled entry")
        click(picker.description_close.get_global_rect().get_center());await frames();check(not picker.description_open and activations==0,"close button does not activate")
        picker.entries[1].description="";picker.open_description();await frames();check(picker.description_text.text.contains("暂无详细说明"),"empty description explicit fallback")
        picker.queue_free();await frames()
    host.queue_free();await frames()
    var app=root.get_node("App");app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();game.select_actor(2);await frames();game.hud.show_abilities();await frames();var picker=game.hud.modal
    picker.entries[0].description=body;var camera=game.camera.transform;var truth=game.battle.snapshot();picker.open_description();await frames()
    var mode=game.mode;key(KEY_DOWN);key(KEY_RIGHT);await frames()
    check(game.camera.transform.is_equal_approx(camera) and game.battle.snapshot()==truth,"description input does not pan map or alter rules")
    picker.close_description();await frames();check(game.mode==mode and game.selected==2,"detail close does not trigger actor autoMove")
    click(picker.cells[0].get_global_rect().get_center());await frames();check(game.mode=="ability:ember","explicit skill targeting survives latest autoMove integration")
    game.hud.show_items();await frames();picker=game.hud.modal;picker.open_description();await frames()
    app.mobile_presentation=true;app.safe_area_override=Rect2i(32,8,root.size.x-64,root.size.y-16);await frames();game.hud.refresh();await frames()
    check(app.ui_safe_rect().encloses(picker.description_panel.get_global_rect()),"expanded details remain in safe area")
    app.return_to_menu();await frames();check(current_scene.scene_file_path=="res://ui/menu.tscn","scene exit frees open description")
    print("PICKER_DESCRIPTION checks=",checks," failures=",failures)
    quit(1 if failures else 0)
