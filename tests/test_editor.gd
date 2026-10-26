extends SceneTree
const Content=preload("res://logic/content.gd")
var failures=0
var checks=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func frames():
    await process_frame
    await process_frame
func run():
    var app=root.get_node("App")
    var editor=load("res://ui/editor.tscn").instantiate();root.add_child(editor);current_scene=editor
    await frames()
    var id="test_bridge_"+str(Time.get_ticks_usec())
    editor.data.id=id;editor.sync_view()
    editor.brush.select(3);editor.paint(Vector2i(0,0))
    check(editor.data.terrain[0][0]=="X","paint obstacle")
    var original=Content.hash_of(editor.data)
    editor.raw.text="{}"
    check(not editor.apply_json() and Content.hash_of(editor.data)==original,"invalid JSON does not replace draft")
    editor.sync_view();editor.perform_save(false)
    var path="user://mods/"+id+".json"
    check(FileAccess.file_exists(path),"save creates actual mod")
    for i in range(editor.mod_picker.item_count):
        if editor.mod_picker.get_item_text(i)==id+".json":editor.mod_picker.select(i)
    editor.data.title="unsaved title";editor.reload_selected()
    check(Content.hash_of(editor.data)==original,"reload restores saved content")
    editor.play();await frames()
    check(current_scene is Node3D and app.session.logic.content.id==id,"editor launches mod battle")
    check(not app.session.logic.walkable(Vector2i(0,0)),"painted terrain reaches shared gameplay content")
    DirAccess.remove_absolute(path)
    print("EDITOR_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
