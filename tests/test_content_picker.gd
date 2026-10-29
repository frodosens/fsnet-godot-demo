extends "res://tests/support/test_case.gd"
const Picker=preload("res://ui/content_picker.gd")
var activations=[]
func _initialize():call_deferred("run")
func frames():
    for i in range(4):await process_frame
func mouse(point,down,button=MOUSE_BUTTON_LEFT,device=0):
    var e=InputEventMouseButton.new();e.position=point;e.button_index=button;e.pressed=down;e.device=device;root.push_input(e,true)
func touch(point,down,index=0,canceled=false):
    var e=InputEventScreenTouch.new();e.position=point;e.pressed=down;e.index=index;e.canceled=canceled;root.push_input(e,true)
func drag(point,index=0):
    var e=InputEventScreenDrag.new();e.position=point;e.index=index;root.push_input(e,true)
func key(code):
    var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;root.push_input(e,true)
func fixture(count):
    var result=[]
    for i in range(count):result.append({"id":"fixture_"+str(i),"name":"测试技能"+str(i),"summary":"MP 2 · 冷却 0","description":"测试说明，只在测试中使用","reason":"法力不足" if i==1 else ""})
    return result
func run():
    var host=Control.new();host.theme=preload("res://ui/style.gd").make_theme();host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(host)
    for viewport in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=viewport;await frames()
        for count in [0,1,8,9,12,37]:
            var picker=Picker.new();picker.title="测试选择器";picker.entries=fixture(count);picker.activated.connect(func(id):activations.append(id));host.add_child(picker);await frames()
            check(picker.cells.size()==count and picker.heading.text.ends_with(str(count)),"dynamic count "+str(count))
            check(picker.panel.get_rect().end.x<=host.size.x and picker.panel.get_rect().end.y<host.size.y,"panel bounded above action row")
            check(picker.back.size.y>=48,"back touch area")
            if count>0:
                check(picker.columns==4,"desktop four columns")
                check(picker.cells[0].size.y>=48 and picker.cells[0].icon!=null,"touch cell and unknown Mod icon fallback")
                var point=picker.cells[0].get_global_rect().get_center()
                var before=activations.size();touch(point,true);drag(point-Vector2(0,35));touch(point-Vector2(0,35),false);await frames()
                check(activations.size()==before,"touch drag release never activates")
                picker.scroll.scroll_vertical=0;await frames()
                if count>1:
                    var disabled=picker.cells[1].get_global_rect().get_center();touch(disabled,true);touch(disabled,false);await frames()
                    check(activations.size()==before and picker.detail.text.contains("法力不足"),"disabled reason visible on tap")
                if count>8:
                    check(picker.scroll.get_v_scroll_bar().max_value>picker.scroll.size.y,"overflow scrolls beyond eight")
                    mouse(point,true,MOUSE_BUTTON_WHEEL_DOWN);await frames();check(picker.scroll.scroll_vertical>0,"wheel scroll")
                    picker.navigate(count);await frames();check(picker.selected_index==count-1 and picker.scroll.scroll_vertical>0,"keyboard last entry reachable")
                picker.scroll.scroll_vertical=0;await frames();point=picker.cells[0].get_global_rect().get_center()
                touch(point,true);touch(point,false);mouse(point,true,MOUSE_BUTTON_LEFT,-1);mouse(point,false,MOUSE_BUTTON_LEFT,-1);await frames()
                check(activations.size()==before+1 and activations.back()=="fixture_0","tap plus emulated mouse activates exactly once")
            else:check(picker.empty.visible and picker.back.has_focus(),"empty return focus")
            picker.queue_free();await frames()
    # Narrow safe region: reduced columns, no tiny targets; physical device density is not emulated.
    host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);host.position=Vector2(32,20);host.size=Vector2(620,620)
    var narrow=Picker.new();narrow.title="窄屏测试";narrow.entries=fixture(37);host.add_child(narrow);await frames()
    check(narrow.columns<4 and narrow.columns>=1,"narrow layout reduces columns")
    check(narrow.panel.get_rect().end.x<=host.size.x and narrow.panel.position.x>=0,"narrow safe bounds")
    check(narrow.cells[0].size.x>=64 and narrow.cells[0].size.y>=64,"narrow cells retain physical touch minimum")
    var p=narrow.cells[0].get_global_rect().get_center();var old=activations.size()
    narrow.activated.connect(func(id):activations.append(id));touch(p,true);touch(p,false,0,true);await frames();check(activations.size()==old,"canceled touch does not choose")
    touch(p,true);host.size.x=590;await frames();touch(p,false);await frames();check(activations.size()==old,"resize cancels gesture")
    narrow.select(2);narrow.cells[2].grab_focus()
    var joy=InputEventJoypadButton.new();joy.button_index=JOY_BUTTON_A;joy.pressed=true;root.push_input(joy,true);await frames();check(activations.size()==old+1,"controller A activates focused enabled entry")
    narrow.queue_free();await frames()
    # Real HUD: snapshot/cost preservation, map targeting, cancel, invalidation and scene exit.
    host.queue_free();await frames()
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.selected=0;game.refresh();var truth=game.battle.snapshot()
    game.hud.show_abilities();await frames();var picker=game.hud.modal
    check(picker is Picker and game.hud.dock.visible and game.hud.dock.actions.visible,"picker preserves horizontal dock and status")
    check(game.hud.turn_button.disabled,"end turn cannot leak through picker")
    check(picker.entries.size()==game.battle.units[0].abilities.size()-1,"actual ability count excludes attack")
    var chosen=picker.entries[0].id;var point=picker.cells[0].get_global_rect().get_center();mouse(point,true);mouse(point,false);await frames()
    check(not is_instance_valid(game.hud.modal) and game.mode=="ability:"+chosen,"first click returns to map targeting")
    check(game.battle.snapshot()==truth,"opening/choosing spends no resources")
    game.hud.show_items();await frames();picker=game.hud.modal
    check(picker.entries[0].summary.contains(str(game.battle.supplies[0])),"actual supplies shown")
    key(KEY_ESCAPE);await frames();check(not is_instance_valid(game.hud.modal),"Escape returns to battle")
    game.hud.show_abilities();await frames();game.selected=1;game.hud.refresh();await frames();check(not is_instance_valid(game.hud.modal),"actor change invalidates picker")
    game.hud.show_abilities();await frames();game.session.connection_generation+=1;game.hud.refresh();await frames();check(not is_instance_valid(game.hud.modal),"reconnection invalidates picker")
    game.selected=2;game.refresh();game.hud.show_abilities();await frames();picker=game.hud.modal
    var original_mode=game.mode;game.session.command_pending=true
    point=picker.cells[0].get_global_rect().get_center();mouse(point,true);mouse(point,false);await frames()
    check(game.mode==original_mode and not is_instance_valid(game.hud.modal),"command pending rejects stale activation")
    game.session.command_pending=false;game.hud.show_abilities();await frames();picker=game.hud.modal;game.session.pending=true
    point=picker.cells[0].get_global_rect().get_center();mouse(point,true);mouse(point,false);await frames()
    check(game.mode=="ability:ember" and not is_instance_valid(game.hud.modal),"ordinary poll does not block local selection")
    game.session.pending=false
    # Logical safe-area layout on landscape phone-sized windows (synthetic, not a device).
    app.mobile_presentation=true;root.min_size=Vector2i(320,240)
    for phone in [Vector2i(1280,720),Vector2i(960,540)]:
        root.size=phone;app.safe_area_override=Rect2i(40,12,phone.x-72,phone.y-24);await frames();game.hud.refresh();game.hud.show_items();await frames()
        picker=game.hud.modal;var rect=picker.panel.get_global_rect();var safe=app.ui_safe_rect()
        check(safe.encloses(rect),"phone panel inside safe area "+str(phone))
        check(game.hud.dock.visible and game.hud.turn_button.disabled,"phone dock visible and noninteractive")
        game.hud.clear_modal();await frames()
    app.safe_area_override=Rect2i();app.mobile_presentation=false
    game.hud.show_items();await frames();app.return_to_menu();await frames();check(current_scene.scene_file_path=="res://ui/menu.tscn","scene exit releases picker")
    print("CONTENT_PICKER checks=",checks," failures=",failures)
    quit(1 if failures else 0)
