extends SceneTree
func _initialize():call_deferred("run")
func frames(n):
    for i in range(n):await process_frame
func run():
    var app=root.get_node("App");app.sfx_enabled=false
    for fixed in [true,false]:
        var data=preload("res://logic/content.gd").reference_content()
        data.units[0].movement=8 # Explicit legal test budget, never changes shipped content.
        app.new_game(data);change_scene_to_file("res://main.tscn");await frames(8)
        while not app.next_story().is_empty():app.advance_story(true)
        var g=current_scene;g.refresh();g.scene_view.set_fixed(fixed);g.hud.choose_action("move")
        var title=preload("res://ui/style.gd").label("原素材模块组装候选 · "+("固定背景" if fixed else "3D")+"\n合法测试移动预算 8 · 实际 Lua 路径",18);title.position=Vector2(300,95);title.mouse_filter=Control.MOUSE_FILTER_IGNORE;g.hud.root.add_child(title)
        for cell in [Vector2i(4,6),Vector2i(3,6),Vector2i(5,6),Vector2i(4,4),Vector2i(1,8)]:
            g.update_move_preview(cell);assert(g.preview_path.size()>1);await frames(70)
        g.clear_move_preview();await frames(30)
        g.update_move_preview(Vector2i(0,7));assert(g.preview_path.is_empty());await frames(25)
        g.update_move_preview(Vector2i(4,4));await frames(60)
        assert(g.stage_move(Vector2i(4,4)));assert(g.confirm_move())
        while g.motion.active():await process_frame
        await frames(40)
    print("ROUTE_ART_RECORD_COMPLETE actual_paths=true no_rule_changes=true");quit()
