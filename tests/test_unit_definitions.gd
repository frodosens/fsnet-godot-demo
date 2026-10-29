extends "res://tests/support/test_case.gd"
func source():
    var d=Content.reference_content().duplicate(true);d.version=2;d.unit_definitions=[]
    var records=[]
    for u in d.units:
        var definition=u.duplicate(true)
        for key in ["x","y","ally","controller","faction","policy","leash","escort"]:definition.erase(key)
        definition.id="template_"+u.id;definition.presentation_ref=u.id
        d.unit_definitions.append(definition)
        var record={"id":u.id,"template_ref":definition.id,"x":u.x,"y":u.y,"ally":u.ally}
        for key in ["controller","faction","policy","leash","escort"]:
            if u.has(key):record[key]=u[key]
        records.append(record)
    d.units=records;return d
func _initialize():
    var original=Content.reference_content();var authored=source()
    require(Content.validate(authored)=="","valid definitions")
    var expanded=Content.expand(authored)
    require(expanded.error=="" and expanded.data.version==1,"canonical expanded content")
    var a=Runtime.new(original);var b=Runtime.new(authored)
    require(b.content.units.is_read_only() and b.content.units[0].is_read_only() and b.content.units[0].abilities.is_read_only(),"deep immutable runtime definitions")
    require(a.snapshot()==b.snapshot(),"expansion preserves snapshot")
    require(b.content_hash==Content.hash_of(authored),"canonical content hash")
    var saved=b.content.duplicate(true);authored.unit_definitions[0].hp+=5
    require(Runtime.new(saved).snapshot()==b.snapshot(),"saved definitions remain frozen")
    require(Content.hash_of(authored)!=b.content_hash,"template edit changes hash")
    for mutation in ["duplicate","unknown","path","override","overflow"]:
        var bad=source()
        match mutation:
            "duplicate":bad.units[1].id=bad.units[0].id
            "unknown":bad.units[0].template_ref="missing"
            "path":bad.unit_definitions[0].presentation_ref="res://evil.gd"
            "override":bad.units[0].damage=40
            "overflow":while bad.units.size()<17:bad.units.append(bad.units[0].duplicate(true))
        require(not Content.validate(bad).is_empty(),"reject "+mutation)
    var reordered=saved.duplicate(true);reordered.units.reverse()
    require(Content.hash_of(saved)!=Content.hash_of(reordered),"order participates in hash")
    # Frozen pre-refactor source is read only from the external QA fixture.
    var path=OS.get_environment("UNIT_BASELINE_LUA")
    if not path.is_empty():
        var old=ClassDB.instantiate("AmberLogic");require(old.load_rules(FileAccess.get_file_as_string(path)),"baseline load")
        old.invoke("reset",{"seed":12345,"content":original})
        var current=Runtime.new(original)
        for step in range(1,9):
            var command={"kind":"end_turn","step":step}
            require(old.invoke("apply",command)==current.apply_command(command),"acceptance parity")
            require(old.invoke("snapshot",{})==current.snapshot(),"snapshot parity "+str(step))
            require(old.invoke("events",{})==current.events,"events parity "+str(step))
    print("UNIT_DEFINITIONS checks=",checks," failures=",failures);quit(1 if failures else 0)
