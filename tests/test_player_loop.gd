extends SceneTree
var app
var game
var checks=0
func verify(ok,label):
    checks+=1
    if not ok:printerr("PLAYER_LOOP_FAIL ",label);quit(1)
    assert(ok,label)
func _initialize():call_deferred("run")
func frames(n=2):
    for i in range(n):await process_frame
func click_at(point):
    var motion=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
    await frames()
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point
        root.push_input(event,true);await process_frame
    await frames()
func button(prefix,node=null):
    if node==null:node=current_scene
    for child in node.find_children("*","BaseButton",true,false):
        if child is Button and child.visible and child.is_visible_in_tree() and not child.disabled and child.text.begins_with(prefix):return child
    return null
func press(prefix):
    var target=button(prefix);verify(target!=null,"visible enabled button: "+prefix)
    if target:await click_at(target.get_global_rect().get_center())
func settle():
    # Fast-forward presentation only, never manufacture a rule result.
    if game and is_instance_valid(game):game.skip_presentation()
    await frames()
    while game and is_instance_valid(game) and game.hud.story_panel.visible:
        await press("跳过本段")
func cell(pos):
    await click_at(game.camera.unproject_position(Vector3(pos.x,0,pos.y)))
    if not game.pending_move.is_empty() or not game.pending_target.is_empty():
        for pressed in [true,false]:
            var key=InputEventKey.new();key.physical_keycode=KEY_ENTER;key.keycode=KEY_ENTER;key.pressed=pressed;root.push_input(key,true);await process_frame
        await frames()
func hero(index):
    # The active hero's companion portrait is hidden; select via board when needed.
    if game.selected==index:return
    var u=game.battle.units[index]
    game.hud.cancel_targeting()
    await cell(u.pos)
    verify(game.selected==index,"select player through board")
func end_turn():
    await click_at(game.hud.turn_button.get_global_rect().get_center())
    if button("确认结束"):await press("确认结束")
    await settle()
func capture(name):
    if DisplayServer.get_name()=="headless":return
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("/tmp/amber-loop-"+name+".png")
func run():
    app=root.get_node("App");app.save_root="user://ui_loop_"+str(Time.get_ticks_usec())
    change_scene_to_file("res://ui/menu.tscn");await frames(6)
    await press("开始新游戏");await frames(5);game=current_scene
    verify(game is Node3D and game.hud.story_panel.visible,"new game reaches intro")
    await press("下一句");verify(app.presentation.line==1,"next dialogue via UI")
    await press("暂停 / 保存");await press("保存旅程");await press("存档一")
    await settle()
    await click_at(game.hud.action_buttons.skill.get_global_rect().get_center());await press("重整")
    var before=game.battle.step;await cell(game.battle.units[0].pos);await settle()
    verify(game.battle.step==before+1,"skill targeting executes via UI")
    await hero(1);await click_at(game.hud.action_buttons.item.get_global_rect().get_center());await press("药房绷带")
    before=game.battle.step;await cell(game.battle.units[0].pos);await settle()
    verify(game.battle.step==before+1 and game.battle.supplies[0]==1,"item targets ally and consumes supply")
    await end_turn();verify(game.battle.round_number==2,"end-turn confirmation executes AI")
    # Play the actual reference scenario using only displayed action buttons and cell clicks.
    for round_index in range(35):
        if game.battle.outcome!="playing":break
        for index in range(3):
            if not game.battle.usable(index):continue
            await hero(index)
            var logic=game.battle;var target=-1;var shortest=999
            for j in range(logic.units.size()):
                if logic.units[j].hp<=0 or logic.units[j].faction==logic.units[index].faction:continue
                var distance=absi(logic.units[index].x-logic.units[j].x)+absi(logic.units[index].y-logic.units[j].y)
                if distance<shortest:shortest=distance;target=j
            if target<0:break
            var best=logic.units[index].pos
            for pos in logic.reachable(index):
                var d=absi(pos.x-logic.units[target].x)+absi(pos.y-logic.units[target].y)
                if d<shortest:shortest=d;best=pos
            if best!=logic.units[index].pos:
                await click_at(game.hud.action_buttons.move.get_global_rect().get_center());await cell(best);await settle()
            if game.battle.outcome!="playing":break
            for j in range(game.battle.units.size()):
                if game.battle.preview_action({"kind":"attack","unit":index,"target":j}).get("legal",false):
                    await click_at(game.hud.action_buttons.attack.get_global_rect().get_center());await cell(game.battle.units[j].pos);await settle();break
        if game.battle.outcome=="playing":await end_turn()
    verify(game.battle.outcome!="playing","UI-driven reference battle terminates")
    verify(game.battle.outcome=="victory" and "ch01_victory" in app.presentation.seen,"victory dialogue completed through UI")
    verify(game.hud.hint_label.text.contains("保存或返回") and game.hud.turn_button.disabled,"terminal UI stops asking for targets")
    await capture("victory")
    print("PLAYER_LOOP terminal=",game.battle.outcome," step=",game.battle.step)
    await click_at(game.hud.pause_button.get_global_rect().get_center());await press("返回主界面")
    if button("保存并离开"):await press("保存并离开")
    await frames(4);await press("读取存档");await press("自动存档");await frames(5);game=current_scene
    verify(game.battle.outcome=="victory" and game.hud.hp_label.text=="%d/%d"%[game.battle.units[maxi(0,game.selected)].hp,game.battle.units[maxi(0,game.selected)].max_hp],"terminal save restores visible HP")
    await click_at(game.hud.pause_button.get_global_rect().get_center());await press("返回主界面");await frames(4)
    await press("读取存档");await press("存档一");await frames(5);game=current_scene
    verify(game.battle.step==0 and app.presentation.line==1 and game.hud.story_panel.visible,"UI load restores original rules and dialogue line")
    await settle()
    for turn in range(60):
        if game.battle.outcome!="playing":break
        await end_turn()
    verify(game.battle.outcome=="defeat" and "ch01_defeat" in app.presentation.seen,"passive UI turns reach defeat dialogue")
    await capture("defeat")
    print("PLAYER_LOOP defeat_step=",game.battle.step)
    print("PLAYER_LOOP_PASS checks=",checks," mouse_buttons_and_cells=true presentation_fast_forward=true")
    quit()
