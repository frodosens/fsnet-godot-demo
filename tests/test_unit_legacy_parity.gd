extends "res://tests/support/test_case.gd"
const C=preload("res://logic/content.gd")
const R=preload("res://logic/runtime.gd")
func _initialize():
    var golden=C.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://tests/unit_baseline_snapshots.json")))
    require(golden.source_commit=="a6da83a74e97fde85b1188646c426e30227a0486" and R.accepts_saved_rules(golden.rules_hash),"frozen predecessor identity")
    for fixture in golden.cases:
        var d=C.from_file("res://"+fixture.path).data
        require(C.hash_of(d)==fixture.content_hash,"content bytes unchanged")
        var r=R.new(d);require(r.snapshot()==fixture.initial,"initial state parity")
        for row in fixture.steps:
            require(r.apply_command(row.command)==row.accepted,"command acceptance parity")
            require(r.snapshot()==row.snapshot,"snapshot parity "+fixture.path)
            require(r.call_rule("events")==row.events,"events parity "+fixture.path)
            var restored=R.new(d);require(restored.restore(row.snapshot) and restored.snapshot()==row.snapshot,"old numeric save restore")
    print("UNIT_LEGACY_PARITY checks=",checks," failures=",failures);quit(1 if failures else 0)
