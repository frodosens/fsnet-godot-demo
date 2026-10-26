extends SceneTree
const Content=preload("res://logic/content.gd")
var checks=0
var failures=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func frames():
    await process_frame
    await process_frame
func run():
    var data=Content.default_content();data.title="自定义关卡"
    data.width=8;data.height=8;data.terrain=[]
    for i in range(8):data.terrain.append("GGGGGGGG")
    var template=data.units[0].duplicate(true);data.units=[]
    for i in range(16):
        var unit=template.duplicate(true);unit.id="crew_"+str(i);unit.name="队员"+str(i);unit.x=i%8;unit.y=i/8;unit.ally=i<15;unit.controller="ai" if i==0 else "player"
        data.units.append(unit)
    data.abilities[1].name="定制恢复";data.abilities[1].effects[0].value=9
    data.consumables=[]
    for i in range(16):data.consumables.append({"id":"kit_"+str(i),"name":"药品"+str(i),"ability":"healing_draught","count":2})
    check(Content.validate(data).is_empty(),"large supported content is valid")
    var app=root.get_node("App");app.new_game(data)
    change_scene_to_file("res://main.tscn");await frames()
    var game=current_scene
    while not app.next_story().is_empty():app.advance_story(true)
    game.selected=1;game.refresh();await frames()
    check(game.hud.detail.tooltip_text.contains("定制恢复") and game.hud.detail.tooltip_text.contains("治疗 9"),"HUD skill name/effects follow content rather than role")
    check(game.hud.hero_column.get_parent() is ScrollContainer and game.hud.hero_column.get_parent().size.y<=460,"supported large party scrolls inside viewport")
    check(game.hud.hero_column.get_child(1).disabled,"friendly AI button is explicitly noncontrollable")
    check(not game.hud.hero_column.get_child(16).disabled,"player controller selectable independently of ally flag")
    var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=game.camera.unproject_position(Vector3(7,0,1))
    game.mode="attack";game._unhandled_input(click)
    check(game.selected==1,"opposing player-controlled target is not selected instead of attacked")
    game.mode="move";game._unhandled_input(click)
    check(game.selected==15,"map selection follows controller independently of faction")
    game.hud.show_items();await frames()
    check(game.hud.modal.get_child(0).get_rect().end.y<=800,"maximum consumable list stays within screen")
    game.hud.clear_modal();game.hud.gear_unit=0;game.hud.show_gear();await frames()
    check(game.hud.gear_unit==1,"gear picker chooses first actual player rather than hardcoded unit zero")
    print("CONTENT_UI_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
