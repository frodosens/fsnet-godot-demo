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
    var form=editor.open_forms();await frames()
    form.controls["/damage"].value=7
    check(form.apply_form(),"unit form validates and applies")
    await frames()
    check(editor.data.units[0].damage==7,"form changes actual content draft")
    var bad_form=editor.open_forms();await frames()
    bad_form.draft.units[0].abilities=["unknown"]
    check(not bad_form.apply_form() and editor.data.units[0].abilities.has("attack"),"form rejects invalid reference atomically")
    bad_form.queue_free();await frames()
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
    check(editor.data.title=="unsaved title" and is_instance_valid(editor.replace_dialog),"reload asks before discarding unsaved content")
    editor.replace_dialog.canceled.emit();await frames()
    check(editor.data.title=="unsaved title","cancel reload preserves edits")
    editor.reload_selected();editor.replace_dialog.confirmed.emit();await frames()
    check(Content.hash_of(editor.data)==original,"confirmed reload restores saved content")
    editor.play();await frames()
    check(current_scene is Node3D and app.session.logic.content.id==id,"editor launches mod battle")
    check(not app.session.logic.walkable(Vector2i(0,0)),"painted terrain reaches shared gameplay content")
    check(app.session.logic.units[0].damage==7,"form-edited stat reaches shared Lua")
    var oversized=Content.default_content()
    for i in range(257):oversized.story.characters.append({"id":"speaker_"+str(i),"name":"角色"})
    check(Content.validate(oversized).contains("预算"),"oversized nested bridge array rejected before VM")
    var incomplete=Content.default_content();incomplete.story.erase("chapterTitle")
    check(not Content.validate(incomplete).is_empty(),"missing narrator chapter title rejected before scene")
    change_scene_to_file("res://ui/editor.tscn")
    await frames();editor=current_scene
    editor.raw.text="{ unfinished JSON draft";editor.raw.text_changed.emit()
    editor.request_back()
    for child in editor.get_children():
        if child is ConfirmationDialog and child.title=="离开工坊？":child.confirmed.emit();break
    await frames();change_scene_to_file("res://ui/editor.tscn");await frames()
    check(current_scene.raw.text=="{ unfinished JSON draft","unapplied even invalid JSON survives menu roundtrip")
    DirAccess.remove_absolute(path)
    print("EDITOR_TESTS checks=",checks," failures=",failures)
    quit(0 if failures==0 else 1)
