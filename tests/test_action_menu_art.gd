extends "res://tests/support/test_case.gd"
var skill_activations=0
func _initialize():call_deferred("run")
func frames(n=3):
    for i in range(n):await process_frame
func key(code):
    for pressed in [true,false]:
        var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event);await process_frame
func run():
    var app=root.get_node("App");app.new_game(Content.reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();var hud=game.hud;var truth=game.battle.snapshot()
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;await frames();hud.refresh();await frames()
        var ratio=float(root.size.x)/root.get_visible_rect().size.x
        for kind in ["move","attack","skill","item"]:
            var b=hud.action_buttons[kind]
            require(b.get_theme_font_size("font_size")*ratio>=16,"physical action font minimum")
            require(b.key_label.text in ["1","2","3","4"] and not b.text.begins_with(b.key_label.text),"key and label are separate native controls")
            require(b.symbol.material is ShaderMaterial,"existing icon has two-tone readability material")
        require(hud.action_panel.mouse_filter==Control.MOUSE_FILTER_IGNORE,"transparent arc container cannot intercept picking")
    var move=hud.action_buttons.move;move.grab_focus();await frames();await key(KEY_DOWN)
    require(hud.action_buttons.attack.has_focus(),"keyboard down traverses action menu")
    var pad=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_DPAD_DOWN;pad.pressed=true;root.push_input(pad,true);await frames();pad.pressed=false;root.push_input(pad,true)
    require(hud.action_buttons.skill.has_focus(),"simulated controller D-pad uses native UI focus")
    hud.action_buttons.skill.pressed.connect(func():skill_activations+=1)
    await key(KEY_ENTER);require(is_instance_valid(hud.modal),"keyboard accept opens real skill panel")
    require(skill_activations==1,"Enter invokes selected action exactly once")
    hud.clear_modal();hud.action_buttons.item.grab_focus();await frames()
    var accept=InputEventJoypadButton.new();accept.button_index=JOY_BUTTON_A;accept.pressed=true;root.push_input(accept,true);await frames();accept.pressed=false;root.push_input(accept,true)
    require(is_instance_valid(hud.modal),"simulated controller accept opens real inventory")
    hud.clear_modal();move.grab_focus();await frames()
    for i in range(12):move.set_selected(i%2==0)
    move.set_selected(true);await create_timer(.2).timeout
    require(move.scale.x<=1.021 and move.hover_amount<=1.001,"repeated selection animation remains bounded")
    require(game.battle.snapshot()==truth,"selection/focus consumes no RNG or actions")
    require(app.session.submit({"kind":"move","unit":0,"x":4,"y":6}),"legal move exhausts move action")
    game.battle=app.session.logic;game.refresh();game.skip_presentation();await create_timer(.2).timeout
    require(move.disabled and move.visual_state=="disabled" and move.hover_amount<.01,"spent option clears highlight and animation")
    print("ACTION_MENU_ART checks=",checks," failures=0 controller=synthetic_input_not_physical_hardware")
    quit()
