extends SceneTree
func _initialize():call_deferred("run")
func run():
    var app=root.get_node("App");app.editor_draft={};app.editor_raw_draft=""
    change_scene_to_file("res://ui/editor.tscn");await process_frame;await process_frame
    var editor=current_scene
    editor.raw.text=JSON.stringify(preload("res://tests/unit_definition_fixture.gd").twins())
    assert(editor.apply_json());assert(editor.data.version==1 and not editor.data.has("unit_definitions"))
    assert(editor.data.units[0].template_ref==editor.data.units[1].template_ref)
    assert(editor.unit_picker.item_count==6)
    print("UNIT_EDITOR checks=4 failures=0");quit()
