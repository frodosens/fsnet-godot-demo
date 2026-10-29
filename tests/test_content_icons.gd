extends "res://tests/support/test_case.gd"
const UI=preload("res://ui/style.gd")
func _initialize():call_deferred("run")
func frames():
    for i in range(4):await process_frame
func buttons(node):
    return node.find_children("*","Button",true,false).filter(func(b):return b.has_meta("content_icon_key"))
func run():
    var mapping=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/bottom_dock_reference/content/content-map.json"))
    for key in mapping:
        var parts=key.split(":");check(UI.content_icon(parts[0],parts[1]) is Texture2D,"known mapping "+key)
    check(UI.content_icon("skill","attack") is Texture2D,"ordinary attack reuses existing sword")
    check(UI.content_icon("item","unknown_mod_id")==null,"unknown Mod retains text fallback")
    var app=root.get_node("App");app.new_game(preload("res://logic/content.gd").reference_content());change_scene_to_file("res://main.tscn");await frames()
    while not app.next_story().is_empty():app.advance_story(true)
    var game=current_scene;game.refresh();check(game.scene_view.active,"ordinary scene uses authored default")
    for size in [Vector2i(1280,800),Vector2i(960,600)]:
        root.size=size;game.selected=2;game.hud.show_abilities();await frames()
        var entries=buttons(game.hud.modal);check(entries.size()==2 and entries.all(func(b):return b.icon!=null),"actual skill list icons")
        entries[0].grab_focus()
        for down in [true,false]:
            var e=InputEventKey.new();e.keycode=KEY_ENTER;e.pressed=down;root.push_input(e,true);await process_frame
        check(game.mode=="ability:ember" and not is_instance_valid(game.hud.modal),"keyboard selects real ability")
        game.hud.show_items();await frames();entries=buttons(game.hud.modal)
        check(entries.size()==1 and entries[0].get_meta("content_icon_key")=="item:bandage" and entries[0].icon!=null,"actual consumable binding")
        if DisplayServer.get_name()!="headless":
            await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/content-items-"+str(size.x)+".png")
        game.hud.clear_modal();game.hud.gear_slot=0;game.hud.show_gear();await frames();entries=buttons(game.hud.modal)
        check(not entries.is_empty() and entries.all(func(b):return b.icon!=null),"equipment quality variants use base icons")
        check(game.hud.modal.get_child(0).get_rect().end.y<=game.get_viewport().get_visible_rect().size.y,"gear pane fits logical viewport")
        if DisplayServer.get_name()!="headless":
            await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/tmp/content-gear-"+str(size.x)+".png")
        game.hud.clear_modal()
    print("CONTENT_ICONS checks=",checks," failures=",failures);quit(1 if failures else 0)
