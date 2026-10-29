extends SceneTree
const C=preload("res://logic/content.gd")
const R=preload("res://logic/runtime.gd")
var checks=0
var failures=0
func check(ok,label):
    checks+=1
    if not ok:failures+=1;push_error(label);quit(1);assert(ok,label)
func _initialize():
    var golden=C.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://tests/unit_baseline_snapshots.json")))
    check(golden.source_commit=="a6da83a74e97fde85b1188646c426e30227a0486" and R.accepts_saved_rules(golden.rules_hash),"frozen predecessor identity")
    for fixture in golden.cases:
        var d=C.from_file("res://"+fixture.path).data
        check(C.hash_of(d)==fixture.content_hash,"content bytes unchanged")
        var r=R.new(d);check(r.snapshot()==fixture.initial,"initial state parity")
        for row in fixture.steps:
            check(r.apply_command(row.command)==row.accepted,"command acceptance parity")
            check(r.snapshot()==row.snapshot,"snapshot parity "+fixture.path)
            check(r.call_rule("events")==row.events,"events parity "+fixture.path)
            var restored=R.new(d);check(restored.restore(row.snapshot) and restored.snapshot()==row.snapshot,"old numeric save restore")
    print("UNIT_LEGACY_PARITY checks=",checks," failures=",failures);quit(1 if failures else 0)
