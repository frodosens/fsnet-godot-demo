extends "res://tests/support/test_case.gd"
func _initialize():call_deferred("run")
func run():
    for entry in preload("res://view/generic_map_art.gd").templates():
        var d=preload("res://logic/content.gd").default_content();d.story.events=[]
        var before=d.units[0].duplicate(true)
        var form=preload("res://ui/content_form.gd").new();form.draft=d;root.add_child(form);await process_frame
        var id_field=form.controls["/id"];id_field.text=entry.id;id_field.text_changed.emit(entry.id)
        require(form.draft.units[0].id==entry.id,"existing stable ID editor control accepts template")
        for key in before:
            if key!="id":require(form.draft.units[0][key]==before[key],"art template does not invent balance "+key)
        require(form.apply_form(),"real form validation/apply")
        await process_frame
    print("GENERIC_EDITOR checks=",checks," failures=0");quit()
