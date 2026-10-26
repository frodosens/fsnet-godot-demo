extends SceneTree
var checks=0
var skill_activations=0
func check(ok,label):
    checks+=1
    if not ok:printerr("FAIL ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func key(code):
    for pressed in [true,false]:
        var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event);await process_frame
func run():
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();var hud=game.hud;var truth=game.battle.snapshot()
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;await frames();hud.refresh();await frames()
        var ratio=float(root.size.x)/root.get_visible_rect().size.x
        for kind in ["move","attack","skill","item"]:
            var b=hud.action_buttons[kind]
            check(b.get_theme_font_size("font_size")*ratio>=16,"physical action font minimum")
            check(b.key_label.text in ["1","2","3","4"] and not b.text.begins_with(b.key_label.text),"key and label are separate native controls")
            check(b.symbol.material is ShaderMaterial,"existing icon has two-tone readability material")
        check(hud.action_shade.visible and hud.action_shade.mouse_filter==Control.MOUSE_FILTER_IGNORE,"local quiet area cannot intercept picking")
    var move=hud.action_buttons.move;move.grab_focus();await frames();await key(KEY_DOWN)
    check(hud.action_buttons.attack.has_focus(),"keyboard down traverses action menu")
    var pad=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_DPAD_DOWN;pad.pressed=true;root.push_input(pad,true);await frames();pad.pressed=false;root.push_input(pad,true)
    check(hud.action_buttons.skill.has_focus(),"simulated controller D-pad uses native UI focus")
    hud.action_buttons.skill.pressed.connect(func():skill_activations+=1)
    await key(KEY_ENTER);check(is_instance_valid(hud.modal),"keyboard accept opens real skill panel")
    check(skill_activations==1,"Enter invokes selected action exactly once")
    hud.clear_modal();hud.action_buttons.item.grab_focus();await frames()
    var accept=InputEventJoypadButton.new();accept.button_index=JOY_BUTTON_A;accept.pressed=true;root.push_input(accept,true);await frames();accept.pressed=false;root.push_input(accept,true)
    check(is_instance_valid(hud.modal),"simulated controller accept opens real inventory")
    hud.clear_modal();move.grab_focus();await frames()
    for i in range(12):move.set_selected(i%2==0)
    move.set_selected(true);await create_timer(.2).timeout
    check(move.scale.x<=1.021 and move.hover_amount<=1.001,"repeated selection animation remains bounded")
    check(game.battle.snapshot()==truth,"selection/focus consumes no RNG or actions")
    check(app.session.submit({"kind":"move","unit":0,"x":4,"y":6}),"legal move exhausts move action")
    game.battle=app.session.logic;game.refresh();game.skip_presentation();await create_timer(.2).timeout
    check(move.disabled and move.visual_state=="disabled" and move.hover_amount<.01,"spent option clears highlight and animation")
    print("ACTION_MENU_ART checks=",checks," failures=0 controller=synthetic_input_not_physical_hardware")
    quit()
