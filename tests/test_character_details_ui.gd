extends SceneTree
class ListFixture:
    extends RefCounted
    var game
    var actual
    var entries=[]
    func picker_entries(_kind):return entries
    func item_text(item):return actual.item_text(item)
var checks=0
var failures=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func frames():
    for i in range(4):await process_frame
func click(point,touch=false):
    for pressed in [true,false]:
        var e=InputEventScreenTouch.new() if touch else InputEventMouseButton.new();e.position=point;e.pressed=pressed
        if not touch:e.button_index=MOUSE_BUTTON_LEFT
        root.push_input(e,true)
func run():
    root.get_node("App").new_game();var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game;await frames();game.hud.advance(true);await frames()
    var original=game.battle.snapshot()
    for resolution in [Vector2i(1280,800),Vector2i(960,600),Vector2i(1200,540),Vector2i(1024,768)]:
        root.size=resolution;await frames()
        click(game.hud.dock.details_button.get_global_rect().get_center());await frames()
        var page=game.hud.modal
        check(is_instance_valid(page),"details button opens")
        if not is_instance_valid(page):continue
        check(page.actor_id==game.battle.units[game.selected].id,"selected actor preserved")
        check(page.panel.get_global_rect().end.x<=game.hud.root.get_global_rect().end.x,"safe horizontal bounds")
        check(page.panel.get_global_rect().end.y<=game.hud.root.get_global_rect().end.y,"safe vertical bounds")
        for tab in range(4):
            click(page.tabs[tab].get_global_rect().get_center(),true);await frames()
            check(page.tab==tab,"touch changes tab")
            if OS.get_environment("DETAILS_CAPTURE")=="1":
                await RenderingServer.frame_post_draw
                root.get_texture().get_image().save_png("/tmp/details-tab-"+str(tab)+"-"+str(resolution.x)+".png")
        check(game.battle.snapshot()==original,"browsing no command")
        if OS.get_environment("DETAILS_CAPTURE")=="1":
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("/tmp/character-details-"+str(resolution.x)+".png")
        page.choose_slot(5);page.choose_equipment(2);await frames();check(not page.equip.disabled,"legal equipment preview")
        click(page.full.get_global_rect().get_center(),true);await frames();check(page.description_open,"full details open")
        click(page.detail_back.get_global_rect().get_center(),true);await frames();check(not page.description_open and page.slot==5,"fulltext back preserves slot")
        click(Vector2(3,3),true);await frames();check(not is_instance_valid(game.hud.modal),"outside touch closes")
        click(game.hud.dock.portrait_button.get_global_rect().get_center(),true);await frames();check(is_instance_valid(game.hud.modal),"portrait touch opens after close")
        if is_instance_valid(game.hud.modal):game.hud.clear_modal()
        await frames()
    game.hud.show_character_details();await frames();var page=game.hud.modal
    page.change_tab(3);page.choose_slot(5);page.choose_equipment(2);await frames()
    var step=game.battle.step
    click(page.equip.get_global_rect().get_center(),true);click(page.equip.get_global_rect().get_center(),true);await frames()
    check(game.battle.step==step+1 and game.battle.units[0].move_actions==2,"actual equip once despite repeated touch")
    check(page.equip.disabled,"already equipped not resubmitted")
    page.choose_equipment(0);game.session.pending=true;await frames();page.commit_equipment()
    check(game.battle.step==step+1,"pending request cannot submit")
    game.session.pending=false
    var pointer=InputEventScreenTouch.new();pointer.position=page.list.get_global_rect().get_center();pointer.pressed=true;root.push_input(pointer,true)
    game.session.pending=true;page.refresh_data();game.session.pending=false;page.refresh_data()
    check(page.pointer==0,"unchanged-state sync pending does not cancel touch gesture")
    pointer=InputEventScreenTouch.new();pointer.position=page.list.get_global_rect().get_center();pointer.pressed=false;pointer.canceled=true;root.push_input(pointer,true)
    var fixture=ListFixture.new();fixture.game=game;fixture.actual=game.hud;page.hud=fixture
    for count in [0,1,8,9,12,37]:
        fixture.entries=[]
        for i in range(count):fixture.entries.append({"id":"fixture_"+str(i),"name":"长名称测试"+str(i),"summary":"库存 ×2","description":"长说明".repeat(50),"reason":"不可用" if i==0 else ""})
        for tab in [1,2]:
            page.change_tab(tab);await frames();check(page.rows.size()==count,"variable skill/item count with no cap")
            if count>0:page.rows[-1].pressed.emit();check(page.body.text.contains("长说明"),"last entry full description accessible")
    page.hud=game.hud;page.change_tab(3)
    page.select_text("long","中文完整描述无空格".repeat(300)+"终点");page.open_description();await frames()
    check(page.detail_text.get_line_count()>20 and page.detail_text.text.ends_with("终点"),"long Chinese wraps without truncation")
    check(page.detail_text.size.x<=page.detail_scroll.size.x,"fulltext fits scroll width")
    page.detail_scroll.scroll_vertical=100000;await frames();check(page.detail_scroll.scroll_vertical>0,"fulltext scrollable")
    page.close_description();var before=game.battle.snapshot();game.session.connection_generation+=1;await frames()
    check(not is_instance_valid(game.hud.modal) and game.battle.snapshot()==before,"reconnect closes stale details safely")
    game.queue_free();await frames();print("CHARACTER_DETAILS_UI checks=",checks," failures=",failures);quit(0 if failures==0 else 1)
