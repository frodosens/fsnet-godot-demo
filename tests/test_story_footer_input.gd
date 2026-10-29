extends "res://tests/support/test_case.gd"
var app
var game
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func find_button(prefix,node):
    for b in node.find_children("*","Button",true,false):
        if b.is_visible_in_tree() and not b.disabled and b.text.begins_with(prefix):return b
    return null
func click(button):
    require(button!=null,"button exists")
    var pos=button.get_global_rect().get_center()
    var motion=InputEventMouseMotion.new();motion.position=pos;root.push_input(motion,true);await frames()
    var hovered=root.gui_get_hovered_control()
    if DisplayServer.get_name()!="headless":
        print("STORY_HOVER wanted=",button.text," actual=",hovered.text if hovered is Button else str(hovered))
        require(hovered==button or button.is_ancestor_of(hovered),"painted button owns pointer: "+button.text)
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=pos;event.pressed=pressed;root.push_input(event,true);await process_frame
    await frames()
func key(code):
    for pressed in [true,false]:
        var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed;root.push_input(e,true);await process_frame
    await frames()
func run():
    app=root.get_node("App");app.save_root="user://story_footer_"+str(Time.get_ticks_usec())
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;change_scene_to_file("res://ui/menu.tscn");await frames(6)
        await click(find_button("开始新游戏",current_scene));await frames(5);game=current_scene
        require(game.hud.story_panel.visible,"intro visible")
        var truth=game.battle.snapshot();var selected=game.selected
        # A click on a different unit above the dialogue must not reach the board.
        var u=game.battle.units[1];var pos=game.camera.unproject_position(Vector3(u.x,0,u.y))
        var motion=InputEventMouseMotion.new();motion.position=pos;root.push_input(motion,true);await frames()
        for pressed in [true,false]:
            var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=pos;e.pressed=pressed;root.push_input(e,true);await process_frame
        require(game.selected==selected and game.battle.snapshot()==truth,"story blocks board input above panel")
        await click(find_button("下一句",game.hud.story_panel));require(app.presentation.line==1,"next advances local story")
        await click(find_button("暂停 / 保存",game.hud.story_panel))
        require(is_instance_valid(game.hud.modal) and not game.hud.story_panel.visible,"story pause opens modal")
        require(not game.hud.dock.is_visible_in_tree() and game.hud.turn_button.disabled,"footer inert behind modal")
        await key(KEY_ESCAPE);require(game.hud.story_panel.visible and not is_instance_valid(game.hud.modal),"Esc resumes same story")
        require(app.presentation.line==1,"resume preserves line")
        require(not game.hud.dock.is_visible_in_tree(),"footer hidden behind story")
        await click(find_button("暂停 / 保存",game.hud.story_panel))
        await click(find_button("保存旅程",game.hud.modal));await click(find_button("存档一",game.hud.modal))
        if is_instance_valid(game.hud.modal):await click(find_button("确认保存",game.hud.modal))
        require(game.hud.story_panel.visible and FileAccess.file_exists(app.save_path("slot1")),"save returns to story")
        await key(KEY_ESCAPE);require(is_instance_valid(game.hud.modal),"Esc opens story pause")
        await click(find_button("继续战斗",game.hud.modal));require(game.hud.story_panel.visible,"button resumes story")
        require(game.battle.snapshot()==truth and game.selected==selected,"no click through to board/end turn")
        await click(find_button("跳过本段",game.hud.story_panel))
        require(not game.hud.story_panel.visible and game.hud.dock.visible and game.hud.dock.actions.visible,"footer actions restore after last line")
        require(not game.hud.turn_button.disabled,"end turn enabled after story")
        await click(game.hud.turn_button);require(is_instance_valid(game.hud.modal),"restored end turn confirmation")
        await click(find_button("继续行动",game.hud.modal));require(not is_instance_valid(game.hud.modal) and game.hud.dock.visible,"cancel restores actions")
        require(game.battle.snapshot()==truth,"cancel never submits turn")
    print("STORY_FOOTER_INPUT checks=",checks," failures=0 actual_viewports=1280x800,960x600");quit()
