extends SceneTree
func _initialize():
    var data=preload("res://tests/unit_definition_fixture.gd").twins()
    assert(Content.validate(data).is_empty())
    var file=FileAccess.open(OS.get_environment("UNIT_FIXTURE_OUT"),FileAccess.WRITE)
    assert(file!=null);file.store_string(JSON.stringify(data));file.close();quit()
